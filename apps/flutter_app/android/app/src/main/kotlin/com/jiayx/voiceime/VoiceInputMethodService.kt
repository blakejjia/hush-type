package com.jiayx.voiceime

import android.Manifest
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.content.pm.PackageManager
import android.inputmethodservice.InputMethodService
import android.media.MediaRecorder
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.util.Log
import android.view.View
import android.view.inputmethod.EditorInfo
import android.widget.TextView
import androidx.core.content.ContextCompat
import okhttp3.Call
import okhttp3.Callback
import okhttp3.HttpUrl.Companion.toHttpUrlOrNull
import okhttp3.MediaType.Companion.toMediaType
import okhttp3.MediaType.Companion.toMediaTypeOrNull
import okhttp3.MultipartBody
import okhttp3.OkHttpClient
import okhttp3.Request
import okhttp3.RequestBody.Companion.asRequestBody
import okhttp3.RequestBody.Companion.toRequestBody
import okhttp3.Response
import org.json.JSONArray
import org.json.JSONObject
import java.io.File
import java.io.IOException

class VoiceInputMethodService : InputMethodService() {

    private data class ProviderConfig(
        val ready: Boolean,
        val statusMessage: String,
        val requestType: String,
        val apiKey: String,
        val endpoint: String,
        val model: String,
        val authType: String,
        val authHeader: String,
        val authPrefix: String,
        val authQueryParam: String,
    )

    private data class LLMConfig(
        val enabled: Boolean,
        val ready: Boolean,
        val statusMessage: String,
        val requestType: String,
        val apiKey: String,
        val endpoint: String,
        val model: String,
        val systemPrompt: String,
        val authType: String,
        val authHeader: String,
        val authPrefix: String,
        val authQueryParam: String,
    )

    private lateinit var keyboardView: View
    private lateinit var btnMic: android.widget.ImageButton
    private lateinit var tvStatus: TextView

    private var isRecording = false
    private var isProcessing = false
    private var recorder: MediaRecorder? = null
    private var outputFilePath: String = ""

    private val client = OkHttpClient()
    private val mainHandler = Handler(Looper.getMainLooper())

    override fun onCreate() {
        super.onCreate()
        outputFilePath = "${cacheDir.absolutePath}/voice_record.m4a"
    }

    override fun onCreateInputView(): View {
        val metrics = resources.displayMetrics
        val density = metrics.density
        val keyboardHeight = (280 * density).toInt()

        val layout = android.widget.LinearLayout(this).apply {
            orientation = android.widget.LinearLayout.VERTICAL
            setBackgroundColor(android.graphics.Color.parseColor("#2D2D2D"))
            gravity = android.view.Gravity.CENTER
            layoutParams = android.view.ViewGroup.LayoutParams(
                android.view.ViewGroup.LayoutParams.MATCH_PARENT,
                keyboardHeight
            )
            minimumHeight = keyboardHeight
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

            background = android.graphics.drawable.GradientDrawable().apply {
                shape = android.graphics.drawable.GradientDrawable.OVAL
                setColor(android.graphics.Color.parseColor("#404040"))
            }
            setOnClickListener { handleMicClick() }
        }

        layout.addView(tvStatus)
        layout.addView(btnMic)
        keyboardView = layout
        return keyboardView
    }

    override fun onComputeInsets(outInsets: Insets) {
        super.onComputeInsets(outInsets)
        if (!isFullscreenMode) {
            outInsets.contentTopInsets = outInsets.visibleTopInsets
        }
    }

    override fun onEvaluateFullscreenMode(): Boolean = false

    override fun onStartInputView(info: EditorInfo?, restarting: Boolean) {
        super.onStartInputView(info, restarting)
        resetUI()
    }

    private fun resetUI() {
        val sttConfig = loadSTTConfig()
        val hasPermission = ContextCompat.checkSelfPermission(
            this,
            Manifest.permission.RECORD_AUDIO
        ) == PackageManager.PERMISSION_GRANTED

        if (!sttConfig.ready) {
            tvStatus.text = sttConfig.statusMessage
            btnMic.alpha = 0.5f
            btnMic.isEnabled = false
        } else if (hasPermission) {
            tvStatus.text = "Ready to record"
            btnMic.alpha = 1.0f
            btnMic.isEnabled = true
        } else {
            tvStatus.text = "Microphone permission required"
            btnMic.alpha = 0.5f
            btnMic.isEnabled = true
        }

        updateMicVisualState()
    }

    private fun handleMicClick() {
        if (isProcessing) {
            return
        }

        val sttConfig = loadSTTConfig()
        if (!sttConfig.ready) {
            tvStatus.text = sttConfig.statusMessage
            updateMicVisualState()
            return
        }

        val hasPermission = ContextCompat.checkSelfPermission(
            this,
            Manifest.permission.RECORD_AUDIO
        ) == PackageManager.PERMISSION_GRANTED
        if (!hasPermission) {
            startActivity(Intent(this, MainActivity::class.java).apply {
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            })
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
            tvStatus.text = "Listening..."
            updateMicVisualState()
        } catch (e: IOException) {
            Log.e("VoiceIME", "Failed to start recording", e)
            recorder?.release()
            recorder = null
            isRecording = false
            isProcessing = false
            updateMicVisualState()
            tvStatus.text = "Error starting mic: ${e.message ?: "unknown"}"
        }
    }

    private fun stopRecordingAndTranscribe() {
        try {
            recorder?.apply {
                stop()
                release()
            }
        } catch (_: RuntimeException) {
        } finally {
            recorder = null
        }

        isRecording = false
        isProcessing = true
        updateMicVisualState()
        tvStatus.text = "Transcribing..."

        val audioFile = File(outputFilePath)
        if (!audioFile.exists() || audioFile.length() == 0L) {
            finishWithError("Recording failed (empty file)")
            return
        }

        val sttConfig = loadSTTConfig()
        if (!sttConfig.ready) {
            finishWithError(sttConfig.statusMessage)
            return
        }

        transcribeAudio(audioFile, sttConfig,
            onSuccess = { transcript ->
                val cleanedTranscript = transcript.trim()
                if (cleanedTranscript.isEmpty()) {
                    finishWithError("The speech-to-text provider returned an empty transcript.")
                    return@transcribeAudio
                }

                maybeRunLanguageModel(cleanedTranscript) { finalText, llmError ->
                    val textToCommit = finalText.trim()
                    if (textToCommit.isEmpty()) {
                        finishWithError(llmError ?: "Nothing to insert.")
                        return@maybeRunLanguageModel
                    }

                    mainHandler.post {
                        commitTextToInput(textToCommit)
                        if (llmError == null) {
                            finishWithStatus("Inserted text")
                        } else {
                            finishWithStatus("Inserted transcript. $llmError")
                        }
                    }
                }
            },
            onError = { message ->
                finishWithError(message)
            }
        )
    }

    private fun transcribeAudio(
        audioFile: File,
        config: ProviderConfig,
        onSuccess: (String) -> Unit,
        onError: (String) -> Unit,
    ) {
        if (config.endpoint.isBlank()) {
            onError(config.statusMessage)
            return
        }

        if (config.requestType != "openai_audio_transcriptions") {
            onError("Unsupported speech-to-text request type in settings JSON.")
            return
        }

        val requestBody = MultipartBody.Builder()
            .setType(MultipartBody.FORM)
            .addFormDataPart("model", config.model)
            .addFormDataPart(
                "file",
                audioFile.name,
                audioFile.asRequestBody("audio/mp4".toMediaTypeOrNull())
            )
            .build()

        val request = Request.Builder()
            .url(config.endpoint)
            .post(requestBody)
            .applyAuth(config.authType, config.authHeader, config.authPrefix, config.apiKey)
            .build()

        client.newCall(request).enqueue(object : Callback {
            override fun onFailure(call: Call, e: IOException) {
                Log.e("VoiceIME", "STT request failed", e)
                onError("Speech-to-text request failed: ${e.message ?: "network error"}")
            }

            override fun onResponse(call: Call, response: Response) {
                response.use {
                    val body = it.body?.string().orEmpty()
                    if (!it.isSuccessful) {
                        onError(extractProviderError(body, it.code, "Speech-to-text request failed"))
                        return
                    }

                    val transcript = parseTranscription(body)
                    if (transcript.isNullOrBlank()) {
                        onError("Speech-to-text response did not include transcript text.")
                        return
                    }

                    onSuccess(transcript)
                }
            }
        })
    }

    private fun maybeRunLanguageModel(
        transcript: String,
        onComplete: (text: String, llmError: String?) -> Unit,
    ) {
        val config = loadLLMConfig()
        if (!config.enabled) {
            onComplete(transcript, null)
            return
        }

        if (!config.ready) {
            onComplete(transcript, null)
            return
        }

        postStatus("Cleaning text...")

        when (config.requestType) {
            "anthropic_messages" -> runAnthropicCleanup(config, transcript, onComplete)
            "gemini_generate_content" -> runGeminiCleanup(config, transcript, onComplete)
            "openai_chat_completions" -> runOpenAICompatibleCleanup(config, transcript, onComplete)
            else -> onComplete(transcript, null)
        }
    }

    private fun runOpenAICompatibleCleanup(
        config: LLMConfig,
        transcript: String,
        onComplete: (text: String, llmError: String?) -> Unit,
    ) {
        if (config.endpoint.isBlank()) {
            onComplete(transcript, config.statusMessage)
            return
        }

        if (config.requestType != "openai_chat_completions") {
            onComplete(transcript, "Unsupported language model request type in settings JSON.")
            return
        }

        val payload = JSONObject()
            .put("model", config.model)
            .put("temperature", 0)
            .put(
                "messages",
                JSONArray()
                    .put(JSONObject().put("role", "system").put("content", config.systemPrompt))
                    .put(JSONObject().put("role", "user").put("content", transcript))
            )

        val request = Request.Builder()
            .url(config.endpoint)
            .header("Content-Type", "application/json")
            .post(payload.toString().toRequestBody("application/json".toMediaType()))
            .applyAuth(config.authType, config.authHeader, config.authPrefix, config.apiKey)
            .build()

        client.newCall(request).enqueue(object : Callback {
            override fun onFailure(call: Call, e: IOException) {
                Log.e("VoiceIME", "LLM request failed", e)
                onComplete(transcript, "Language model request failed: ${e.message ?: "network error"}")
            }

            override fun onResponse(call: Call, response: Response) {
                response.use {
                    val body = it.body?.string().orEmpty()
                    if (!it.isSuccessful) {
                        onComplete(
                            transcript,
                            extractProviderError(body, it.code, "Language model request failed")
                        )
                        return
                    }

                    val parsed = parseOpenAICompatibleMessage(body)
                    if (parsed.isNullOrBlank()) {
                        onComplete(transcript, "Language model response did not include text.")
                        return
                    }

                    onComplete(parsed, null)
                }
            }
        })
    }

    private fun runAnthropicCleanup(
        config: LLMConfig,
        transcript: String,
        onComplete: (text: String, llmError: String?) -> Unit,
    ) {
        val payload = JSONObject()
            .put("model", config.model)
            .put("max_tokens", 512)
            .put("system", config.systemPrompt)
            .put(
                "messages",
                JSONArray().put(
                    JSONObject()
                        .put("role", "user")
                        .put("content", JSONArray().put(JSONObject().put("type", "text").put("text", transcript)))
                )
            )

        if (config.endpoint.isBlank() || config.requestType != "anthropic_messages") {
            onComplete(transcript, config.statusMessage)
            return
        }

        val request = Request.Builder()
            .url(config.endpoint)
            .header("anthropic-version", "2023-06-01")
            .header("content-type", "application/json")
            .post(payload.toString().toRequestBody("application/json".toMediaType()))
            .applyAuth(config.authType, config.authHeader, config.authPrefix, config.apiKey)
            .build()

        client.newCall(request).enqueue(object : Callback {
            override fun onFailure(call: Call, e: IOException) {
                Log.e("VoiceIME", "Anthropic request failed", e)
                onComplete(transcript, "Language model request failed: ${e.message ?: "network error"}")
            }

            override fun onResponse(call: Call, response: Response) {
                response.use {
                    val body = it.body?.string().orEmpty()
                    if (!it.isSuccessful) {
                        onComplete(
                            transcript,
                            extractProviderError(body, it.code, "Language model request failed")
                        )
                        return
                    }

                    val parsed = parseAnthropicMessage(body)
                    if (parsed.isNullOrBlank()) {
                        onComplete(transcript, "Language model response did not include text.")
                        return
                    }

                    onComplete(parsed, null)
                }
            }
        })
    }

    private fun runGeminiCleanup(
        config: LLMConfig,
        transcript: String,
        onComplete: (text: String, llmError: String?) -> Unit,
    ) {
        if (config.endpoint.isBlank() || config.requestType != "gemini_generate_content") {
            onComplete(transcript, config.statusMessage)
            return
        }

        val url = config.endpoint.toHttpUrlOrNull()
            ?.newBuilder()
            ?.applyQueryAuth(config.authType, config.authQueryParam, config.apiKey)
            ?.build()
            ?: run {
                onComplete(transcript, "Invalid language model endpoint.")
                return
            }

        val payload = JSONObject()
            .put(
                "systemInstruction",
                JSONObject().put(
                    "parts",
                    JSONArray().put(JSONObject().put("text", config.systemPrompt))
                )
            )
            .put(
                "contents",
                JSONArray().put(
                    JSONObject()
                        .put("role", "user")
                        .put("parts", JSONArray().put(JSONObject().put("text", transcript)))
                )
            )

        val request = Request.Builder()
            .url(url)
            .header("content-type", "application/json")
            .post(payload.toString().toRequestBody("application/json".toMediaType()))
            .build()

        client.newCall(request).enqueue(object : Callback {
            override fun onFailure(call: Call, e: IOException) {
                Log.e("VoiceIME", "Gemini request failed", e)
                onComplete(transcript, "Language model request failed: ${e.message ?: "network error"}")
            }

            override fun onResponse(call: Call, response: Response) {
                response.use {
                    val body = it.body?.string().orEmpty()
                    if (!it.isSuccessful) {
                        onComplete(
                            transcript,
                            extractProviderError(body, it.code, "Language model request failed")
                        )
                        return
                    }

                    val parsed = parseGeminiMessage(body)
                    if (parsed.isNullOrBlank()) {
                        onComplete(transcript, "Language model response did not include text.")
                        return
                    }

                    onComplete(parsed, null)
                }
            }
        })
    }

    private fun loadSTTConfig(): ProviderConfig {
        val prefs = getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
        val settings = parseJsonObject(prefs.getStringCompat("flutter.stt_settings"))
        val runtime = settings?.optJSONObject("runtime")
        val auth = runtime?.optJSONObject("auth")

        return ProviderConfig(
            ready = runtime?.optBoolean("ready", false) ?: false,
            statusMessage = runtime?.optString("status_message").orFallback(
                null,
                "Please configurate first before using."
            ),
            requestType = runtime?.optString("request_type").orFallback(null, ""),
            apiKey = runtime?.optString("api_key").orFallback(null, ""),
            endpoint = runtime?.optString("endpoint").orFallback(null, ""),
            model = runtime?.optString("model").orFallback(null, ""),
            authType = auth?.optString("type").orFallback(null, "bearer"),
            authHeader = auth?.optString("header").orFallback(null, "Authorization"),
            authPrefix = auth?.optString("prefix").orFallback(null, "Bearer "),
            authQueryParam = auth?.optString("query_param").orFallback(null, ""),
        )
    }

    private fun loadLLMConfig(): LLMConfig {
        val prefs = getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
        val settings = parseJsonObject(prefs.getStringCompat("flutter.llm_settings"))
        val runtime = settings?.optJSONObject("runtime")
        val auth = runtime?.optJSONObject("auth")

        return LLMConfig(
            enabled = runtime?.optBoolean("enabled", settings?.optBoolean("enabled", true) ?: true)
                ?: true,
            ready = runtime?.optBoolean("ready", false) ?: false,
            statusMessage = runtime?.optString("status_message").orFallback(
                null,
                "Language model cleanup is not configured."
            ),
            requestType = runtime?.optString("request_type").orFallback(null, ""),
            apiKey = runtime?.optString("api_key").orFallback(null, ""),
            endpoint = runtime?.optString("endpoint").orFallback(null, ""),
            model = runtime?.optString("model").orFallback(null, ""),
            systemPrompt = runtime?.optString("system_prompt").orFallback(
                null,
                DEFAULT_SYSTEM_PROMPT
            ),
            authType = auth?.optString("type").orFallback(null, "bearer"),
            authHeader = auth?.optString("header").orFallback(null, "Authorization"),
            authPrefix = auth?.optString("prefix").orFallback(null, "Bearer "),
            authQueryParam = auth?.optString("query_param").orFallback(null, ""),
        )
    }

    private fun parseTranscription(body: String): String? {
        val json = parseJsonObject(body) ?: return body.trim().ifBlank { null }

        val directText = json.optString("text").trim()
        if (directText.isNotEmpty()) {
            return directText
        }

        val nestedText = json.optJSONObject("data")?.optString("text").orEmpty().trim()
        return nestedText.ifBlank { null }
    }

    private fun parseOpenAICompatibleMessage(body: String): String? {
        val json = parseJsonObject(body) ?: return null
        val choices = json.optJSONArray("choices") ?: return null
        if (choices.length() == 0) {
            return null
        }

        val message = choices.optJSONObject(0)?.optJSONObject("message")
        val content = message?.opt("content")
        return parseFlexibleContent(content)
    }

    private fun parseAnthropicMessage(body: String): String? {
        val json = parseJsonObject(body) ?: return null
        return parseFlexibleContent(json.opt("content"))
    }

    private fun parseGeminiMessage(body: String): String? {
        val json = parseJsonObject(body) ?: return null
        val candidates = json.optJSONArray("candidates") ?: return null
        if (candidates.length() == 0) {
            return null
        }

        val content = candidates.optJSONObject(0)
            ?.optJSONObject("content")
            ?.optJSONArray("parts")

        return parseFlexibleContent(content)
    }

    private fun parseFlexibleContent(content: Any?): String? {
        return when (content) {
            is String -> content.trim().ifBlank { null }
            is JSONArray -> buildString {
                for (index in 0 until content.length()) {
                    val part = content.opt(index)
                    when (part) {
                        is String -> {
                            if (part.isNotBlank()) {
                                if (isNotEmpty()) append('\n')
                                append(part.trim())
                            }
                        }
                        is JSONObject -> {
                            val text = part.optString("text").trim()
                            if (text.isNotEmpty()) {
                                if (isNotEmpty()) append('\n')
                                append(text)
                            }
                        }
                    }
                }
            }.trim().ifBlank { null }
            is JSONObject -> content.optString("text").trim().ifBlank { null }
            else -> null
        }
    }

    private fun extractProviderError(body: String, statusCode: Int, fallback: String): String {
        val json = parseJsonObject(body)
        if (json != null) {
            val nestedError = json.optJSONObject("error")
            val nestedMessage = nestedError?.optString("message").orEmpty().trim()
            if (nestedMessage.isNotEmpty()) {
                return nestedMessage
            }

            val message = json.optString("message").trim()
            if (message.isNotEmpty()) {
                return message
            }

            val errorStatus = json.optString("status").trim()
            if (errorStatus.isNotEmpty()) {
                return errorStatus
            }
        }

        val trimmed = body.trim()
        if (trimmed.isNotEmpty()) {
            return trimmed.take(240)
        }

        return "$fallback ($statusCode)"
    }

    private fun commitTextToInput(text: String) {
        currentInputConnection?.commitText(text, 1)
    }

    private fun finishWithStatus(message: String) {
        mainHandler.post {
            isProcessing = false
            updateMicVisualState()
            tvStatus.text = message
            mainHandler.postDelayed({ resetUI() }, 1800)
        }
    }

    private fun finishWithError(message: String) {
        mainHandler.post {
            isProcessing = false
            updateMicVisualState()
            tvStatus.text = message
            mainHandler.postDelayed({ resetUI() }, 2600)
        }
    }

    private fun postStatus(message: String) {
        mainHandler.post {
            tvStatus.text = message
        }
    }

    private fun updateMicVisualState() {
        val color = when {
            isRecording -> android.graphics.Color.RED
            isProcessing -> android.graphics.Color.parseColor("#606060")
            else -> android.graphics.Color.parseColor("#404040")
        }

        val sttReady = loadSTTConfig().ready
        (btnMic.background as? android.graphics.drawable.GradientDrawable)?.setColor(color)
        btnMic.isEnabled = !isProcessing && sttReady
        btnMic.alpha = when {
            isProcessing -> 0.7f
            !sttReady -> 0.5f
            else -> 1.0f
        }
    }

    private fun parseJsonObject(raw: String?): JSONObject? {
        if (raw.isNullOrBlank()) {
            return null
        }

        return try {
            JSONObject(raw)
        } catch (_: Exception) {
            null
        }
    }

    private fun String?.orFallback(fallback: String?, defaultValue: String): String {
        val primary = this?.trim().orEmpty()
        if (primary.isNotEmpty()) {
            return primary
        }

        val secondary = fallback?.trim().orEmpty()
        if (secondary.isNotEmpty()) {
            return secondary
        }

        return defaultValue
    }

    private fun SharedPreferences.getStringCompat(key: String): String? {
        return getString("flutter.$key", null) ?: getString(key, null)
    }

    private fun Request.Builder.applyAuth(
        authType: String,
        authHeader: String,
        authPrefix: String,
        apiKey: String,
    ): Request.Builder {
        return when (authType) {
            "header", "bearer" -> {
                if (apiKey.isNotBlank() && authHeader.isNotBlank()) {
                    header(authHeader, "$authPrefix$apiKey")
                }
                this
            }
            else -> this
        }
    }

    private fun okhttp3.HttpUrl.Builder.applyQueryAuth(
        authType: String,
        authQueryParam: String,
        apiKey: String,
    ): okhttp3.HttpUrl.Builder {
        if (authType == "query" && authQueryParam.isNotBlank() && apiKey.isNotBlank()) {
            addQueryParameter(authQueryParam, apiKey)
        }
        return this
    }

    companion object {
        private const val DEFAULT_SYSTEM_PROMPT =
            "You are a assistant doing text cleanup. User prompt is directly from user's mouth. " +
                "Clean up transcriptions, and fix errors while preserving your tone.\n\n" +
                "ATTENTION: DO NOT MODIFY the user's sentences, just reformat and clean the words like \"ah, En\" " +
                "Even given a clear task, DO NOT DO THAT, remember you are a words cleaner, not task completer!"
    }
}
