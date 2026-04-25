package com.jiayx.voiceime

import android.Manifest
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.inputmethodservice.InputMethodService
import android.media.MediaRecorder
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.util.Log
import android.view.View
import android.view.inputmethod.EditorInfo
import android.widget.Button
import android.widget.TextView
import androidx.core.content.ContextCompat
import okhttp3.*
import okhttp3.MediaType.Companion.toMediaTypeOrNull
import okhttp3.RequestBody.Companion.asRequestBody
import org.json.JSONObject
import java.io.File
import java.io.IOException

class VoiceInputMethodService : InputMethodService() {

    private lateinit var keyboardView: View
    private lateinit var btnMic: android.widget.ImageButton
    private lateinit var tvStatus: TextView
    private var isRecording = false
    private var recorder: MediaRecorder? = null
    private var outputFilePath: String = ""
    private val client = OkHttpClient()

    override fun onCreate() {
        super.onCreate()
        outputFilePath = "${cacheDir.absolutePath}/voice_record.m4a"
    }

    override fun onCreateInputView(): View {
        val metrics = resources.displayMetrics
        val density = metrics.density
        // If density seems too low for a modern device, it might be a context issue.
        // But 280dp is the target.
        val keyboardHeight = (280 * density).toInt()

        val layout = android.widget.LinearLayout(this).apply {
            orientation = android.widget.LinearLayout.VERTICAL
            setBackgroundColor(android.graphics.Color.parseColor("#2D2D2D"))
            gravity = android.view.Gravity.CENTER
            
            // CRITICAL: Force the height to 280dp using both layoutParams and minimumHeight
            layoutParams = android.view.ViewGroup.LayoutParams(
                android.view.ViewGroup.LayoutParams.MATCH_PARENT,
                keyboardHeight
            )
            minimumHeight = keyboardHeight
            
            // Add some padding at the bottom to avoid being too close to the system navigation bar
            setPadding(0, 0, 0, (20 * density).toInt())
        }

        tvStatus = TextView(this).apply {
            text = "Ready to record"
            setTextColor(android.graphics.Color.WHITE)
            textSize = 20f
            setPadding(0, 0, 0, (30 * density).toInt())
            gravity = android.view.Gravity.CENTER
        }

        btnMic = android.widget.ImageButton(this).apply {
            setImageResource(android.R.drawable.ic_btn_speak_now)
            scaleType = android.widget.ImageView.ScaleType.FIT_CENTER
            val btnSize = (90 * density).toInt()
            layoutParams = android.widget.LinearLayout.LayoutParams(btnSize, btnSize)
            
            // Use a nicer background for the mic button
            val ripple = android.graphics.drawable.GradientDrawable().apply {
                shape = android.graphics.drawable.GradientDrawable.OVAL
                setColor(android.graphics.Color.parseColor("#404040"))
            }
            background = ripple
            setOnClickListener { handleMicClick() }
        }

        layout.addView(tvStatus)
        layout.addView(btnMic)
        keyboardView = layout
        return keyboardView
    }

    override fun onComputeInsets(outInsets: Insets) {
        super.onComputeInsets(outInsets)
        // Ensure the system knows the full height of our input view
        if (!isFullscreenMode) {
            outInsets.contentTopInsets = outInsets.visibleTopInsets
        }
    }

    override fun onEvaluateFullscreenMode(): Boolean {
        // Prevent the keyboard from taking over the whole screen in landscape
        return false
    }

    override fun onStartInputView(info: EditorInfo?, restarting: Boolean) {
        super.onStartInputView(info, restarting)
        resetUI()
    }

    private fun resetUI() {
        val hasPermission = ContextCompat.checkSelfPermission(this, Manifest.permission.RECORD_AUDIO) == PackageManager.PERMISSION_GRANTED
        if (hasPermission) {
            tvStatus.text = "Ready to record"
            btnMic.alpha = 1.0f
            btnMic.setBackgroundColor(android.graphics.Color.TRANSPARENT)
            isRecording = false
        } else {
            tvStatus.text = "Microphone permission required"
            btnMic.alpha = 0.5f
            isRecording = false
        }
    }

    private fun handleMicClick() {
        val hasPermission = ContextCompat.checkSelfPermission(this, Manifest.permission.RECORD_AUDIO) == PackageManager.PERMISSION_GRANTED
        if (!hasPermission) {
            val intent = Intent(this, MainActivity::class.java).apply {
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            }
            startActivity(intent)
            return
        }

        if (isRecording) {
            stopRecordingAndTranscribe()
        } else {
            startRecording()
        }
    }

    private fun startRecording() {
        try {
            recorder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                MediaRecorder(this)
            } else {
                @Suppress("DEPRECATION")
                MediaRecorder()
            }

            recorder?.apply {
                setAudioSource(MediaRecorder.AudioSource.MIC)
                setOutputFormat(MediaRecorder.OutputFormat.MPEG_4)
                setAudioEncoder(MediaRecorder.AudioEncoder.AAC)
                setOutputFile(outputFilePath)
                prepare()
                start()
            }
            
            isRecording = true
            btnMic.setBackgroundColor(android.graphics.Color.RED)
            tvStatus.text = "Listening..."
        } catch (e: IOException) {
            tvStatus.text = "Error starting mic: ${e.message}"
            isRecording = false
            recorder?.release()
            recorder = null
        }
    }

    private fun stopRecordingAndTranscribe() {
        try {
            recorder?.apply {
                stop()
                release()
            }
        } catch (e: RuntimeException) {
            // Stop can throw RuntimeException if called immediately after start
        } finally {
            recorder = null
        }
        
        isRecording = false
        btnMic.setBackgroundColor(android.graphics.Color.TRANSPARENT)
        tvStatus.text = "Transcribing..."

        // Ensure file exists and has size
        val audioFile = File(outputFilePath)
        if (!audioFile.exists() || audioFile.length() == 0L) {
            tvStatus.text = "Recording failed (empty file)"
            return
        }

        // Retrieve settings from Flutter's SharedPreferences
        val prefs = getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
        // Flutter's shared_preferences plugin prefixes keys with 'flutter.'
        // Note: if the flutter code sets 'flutter.stt_api_key', it becomes 'flutter.flutter.stt_api_key'
        val apiKey = prefs.getString("flutter.flutter.stt_api_key", "") ?: prefs.getString("flutter.stt_api_key", "") ?: ""
        val model = prefs.getString("flutter.flutter.stt_model", "whisper-1") ?: prefs.getString("flutter.stt_model", "whisper-1") ?: "whisper-1"

        if (apiKey.isEmpty()) {
            tvStatus.text = "API Key missing in settings!"
            Handler(Looper.getMainLooper()).postDelayed({ resetUI() }, 3000)
            return
        }

        // Upload to Firebase Cloud Function
        // Using emulator for now or direct prod URL? Assuming prod or a valid emulator proxy.
        // TODO: Replace with your actual deployed Firebase Function URL or emulator IP
        val url = "http://10.0.2.2:5001/YOUR_PROJECT_ID/us-central1/transcribeAudio" // Local emulator for android

        val requestBody = MultipartBody.Builder()
            .setType(MultipartBody.FORM)
            .addFormDataPart("apiKey", apiKey)
            .addFormDataPart("model", model)
            .addFormDataPart(
                "audio",
                "voice_record.m4a",
                audioFile.asRequestBody("audio/mp4".toMediaTypeOrNull())
            )
            .build()

        val request = Request.Builder()
            .url(url)
            .post(requestBody)
            .build()

        client.newCall(request).enqueue(object : Callback {
            override fun onFailure(call: Call, e: IOException) {
                Log.e("VoiceIME", "Network error", e)
                Handler(Looper.getMainLooper()).post {
                    tvStatus.text = "Network Error"
                    Handler(Looper.getMainLooper()).postDelayed({ resetUI() }, 3000)
                }
            }

            override fun onResponse(call: Call, response: Response) {
                val responseData = response.body?.string()
                Log.d("VoiceIME", "Response: $responseData")
                Handler(Looper.getMainLooper()).post {
                    if (response.isSuccessful && responseData != null) {
                        try {
                            val json = JSONObject(responseData)
                            if (json.optInt("code") == 0) {
                                val text = json.getJSONObject("data").getString("text")
                                commitTextToInput(text)
                                tvStatus.text = "Success!"
                            } else {
                                tvStatus.text = "Error: ${json.optString("message")}"
                            }
                        } catch (e: Exception) {
                            tvStatus.text = "Invalid Response"
                        }
                    } else {
                        tvStatus.text = "Server Error ${response.code}"
                    }
                    Handler(Looper.getMainLooper()).postDelayed({ resetUI() }, 2000)
                }
            }
        })
    }

    private fun commitTextToInput(text: String) {
        val ic = currentInputConnection
        ic?.commitText(text, 1)
    }
}