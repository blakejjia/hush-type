package com.jiayx.voiceime

import android.Manifest
import android.content.Intent
import android.content.pm.PackageManager
import android.inputmethodservice.InputMethodService
import android.media.MediaRecorder
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.view.View
import android.view.inputmethod.EditorInfo
import android.widget.Button
import android.widget.TextView
import androidx.core.content.ContextCompat
import java.io.File
import java.io.IOException

class VoiceInputMethodService : InputMethodService() {

    private lateinit var keyboardView: View
    private lateinit var btnMic: android.widget.ImageButton
    private lateinit var tvStatus: TextView
    private var isRecording = false
    private var recorder: MediaRecorder? = null
    private var outputFilePath: String = ""

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

        // TODO: 1. 读取 SharedPreferences 获取 Firebase Token
        // TODO: 2. 上传文件到 Firebase Function

        // Mock 网络回调成功后写入文本
        mockNetworkCall { transcribedText ->
            commitTextToInput(transcribedText)
            tvStatus.text = "Success!"
            
            // Post delayed reset
            Handler(Looper.getMainLooper()).postDelayed({
                if (!isRecording) {
                    resetUI()
                }
            }, 2000)
        }
    }

    private fun commitTextToInput(text: String) {
        val ic = currentInputConnection
        ic?.commitText(text, 1)
    }

    private fun mockNetworkCall(callback: (String) -> Unit) {
        Handler(Looper.getMainLooper()).postDelayed({
            // Phase 1 Mocking the transcribe action
            callback("Hello, this is a mock transcription from Phase 1.")
        }, 1500)
    }
}