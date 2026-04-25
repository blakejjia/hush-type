package com.jia_yx.hashtype

import android.Manifest
import android.content.Context
import android.content.pm.PackageManager
import android.media.MediaRecorder
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.util.Log
import androidx.core.content.ContextCompat
import okhttp3.*
import okhttp3.HttpUrl.Companion.toHttpUrlOrNull
import okhttp3.MediaType.Companion.toMediaType
import okhttp3.MediaType.Companion.toMediaTypeOrNull
import okhttp3.RequestBody.Companion.asRequestBody
import okhttp3.RequestBody.Companion.toRequestBody
import org.json.JSONArray
import org.json.JSONObject
import java.io.File
import java.io.IOException

class VoiceImeViewModel(private val context: Context) {

    interface Listener {
        fun onStateChanged(state: ImeState)
        fun onStatusMessageChanged(message: String)
        fun onTextCommitted(text: String)
        fun onOpenSettings()
    }

    sealed class ImeState {
        object Idle : ImeState()
        object Recording : ImeState()
        object Processing : ImeState()
        data class Error(val message: String) : ImeState()
        data class Success(val message: String) : ImeState()
    }

    private var listener: Listener? = null
    private var state: ImeState = ImeState.Idle
    private var recorder: MediaRecorder? = null
    private val outputFilePath: String = "${context.cacheDir.absolutePath}/voice_record.m4a"
    private val client = OkHttpClient()
    private val mainHandler = Handler(Looper.getMainLooper())

    fun setListener(listener: Listener) {
        this.listener = listener
    }

    fun reset() {
        val sttConfig = ImeSettingsResolver.loadSTTConfig(context)
        val hasPermission = ContextCompat.checkSelfPermission(
            context,
            Manifest.permission.RECORD_AUDIO
        ) == PackageManager.PERMISSION_GRANTED

        if (!sttConfig.ready) {
            updateState(ImeState.Error(sttConfig.statusMessage))
        } else if (!hasPermission) {
            updateState(ImeState.Error("Microphone permission required"))
        } else {
            updateState(ImeState.Idle)
            listener?.onStatusMessageChanged("Ready to record")
        }
    }

    fun handleMicClick() {
        if (state is ImeState.Processing) return

        val sttConfig = ImeSettingsResolver.loadSTTConfig(context)
        if (!sttConfig.ready) {
            updateState(ImeState.Error(sttConfig.statusMessage))
            return
        }

        val hasPermission = ContextCompat.checkSelfPermission(
            context,
            Manifest.permission.RECORD_AUDIO
        ) == PackageManager.PERMISSION_GRANTED
        if (!hasPermission) {
            listener?.onOpenSettings()
            return
        }

        if (state is ImeState.Recording) {
            stopRecordingAndTranscribe()
        } else {
            startRecording()
        }
    }

    private fun startRecording() {
        try {
            recorder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                MediaRecorder(context)
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

            updateState(ImeState.Recording)
            listener?.onStatusMessageChanged("Listening...")
        } catch (e: IOException) {
            Log.e("VoiceImeVM", "Failed to start recording", e)
            recorder?.release()
            recorder = null
            updateState(ImeState.Error("Error starting mic: ${e.message ?: "unknown"}"))
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

        updateState(ImeState.Processing)
        listener?.onStatusMessageChanged("Transcribing...")

        val audioFile = File(outputFilePath)
        if (!audioFile.exists() || audioFile.length() == 0L) {
            finishWithError("Recording failed (empty file)")
            return
        }

        val sttConfig = ImeSettingsResolver.loadSTTConfig(context)
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
                        listener?.onTextCommitted(textToCommit)
                        if (llmError == null) {
                            finishWithSuccess("Inserted text")
                        } else {
                            finishWithSuccess("Inserted transcript. $llmError")
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
            .build()
            .withAuth(config)

        client.newCall(request).enqueue(object : Callback {
            override fun onFailure(call: Call, e: IOException) {
                Log.e("VoiceImeVM", "STT request failed", e)
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
        val config = ImeSettingsResolver.loadLLMConfig(context)
        if (!config.enabled || !config.ready) {
            onComplete(transcript, null)
            return
        }

        mainHandler.post { listener?.onStatusMessageChanged("Cleaning text...") }

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
            .build()
            .withAuth(config)

        client.newCall(request).enqueue(object : Callback {
            override fun onFailure(call: Call, e: IOException) {
                onComplete(transcript, "Language model request failed: ${e.message ?: "network error"}")
            }

            override fun onResponse(call: Call, response: Response) {
                response.use {
                    val body = it.body?.string().orEmpty()
                    if (!it.isSuccessful) {
                        onComplete(transcript, extractProviderError(body, it.code, "Language model request failed"))
                        return
                    }
                    val parsed = parseOpenAICompatibleMessage(body)
                    onComplete(parsed ?: transcript, if (parsed == null) "Response missing text" else null)
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

        val request = Request.Builder()
            .url(config.endpoint)
            .header("anthropic-version", "2023-06-01")
            .header("content-type", "application/json")
            .post(payload.toString().toRequestBody("application/json".toMediaType()))
            .build()
            .withAuth(config)

        client.newCall(request).enqueue(object : Callback {
            override fun onFailure(call: Call, e: IOException) {
                onComplete(transcript, "Language model request failed: ${e.message ?: "network error"}")
            }

            override fun onResponse(call: Call, response: Response) {
                response.use {
                    val body = it.body?.string().orEmpty()
                    if (!it.isSuccessful) {
                        onComplete(transcript, extractProviderError(body, it.code, "Language model request failed"))
                        return
                    }
                    val parsed = parseAnthropicMessage(body)
                    onComplete(parsed ?: transcript, if (parsed == null) "Response missing text" else null)
                }
            }
        })
    }

    private fun runGeminiCleanup(
        config: LLMConfig,
        transcript: String,
        onComplete: (text: String, llmError: String?) -> Unit,
    ) {
        val url = config.endpoint.toHttpUrlOrNull()
            ?.newBuilder()
            ?.applyQueryAuth(config.authType, config.authQueryParam, config.apiKey)
            ?.build()
            ?: run {
                onComplete(transcript, "Invalid language model endpoint.")
                return
            }

        val payload = JSONObject()
            .put("systemInstruction", JSONObject().put("parts", JSONArray().put(JSONObject().put("text", config.systemPrompt))))
            .put("contents", JSONArray().put(JSONObject().put("role", "user").put("parts", JSONArray().put(JSONObject().put("text", transcript)))))

        val request = Request.Builder()
            .url(url)
            .header("content-type", "application/json")
            .post(payload.toString().toRequestBody("application/json".toMediaType()))
            .build()

        client.newCall(request).enqueue(object : Callback {
            override fun onFailure(call: Call, e: IOException) {
                onComplete(transcript, "Language model request failed: ${e.message ?: "network error"}")
            }

            override fun onResponse(call: Call, response: Response) {
                response.use {
                    val body = it.body?.string().orEmpty()
                    if (!it.isSuccessful) {
                        onComplete(transcript, extractProviderError(body, it.code, "Language model request failed"))
                        return
                    }
                    val parsed = parseGeminiMessage(body)
                    onComplete(parsed ?: transcript, if (parsed == null) "Response missing text" else null)
                }
            }
        })
    }

    private fun parseTranscription(body: String): String? {
        val json = parseJsonObject(body) ?: return body.trim().ifBlank { null }
        val directText = json.optString("text").trim()
        if (directText.isNotEmpty()) return directText
        return json.optJSONObject("data")?.optString("text")?.trim()?.ifBlank { null }
    }

    private fun parseOpenAICompatibleMessage(body: String): String? {
        val json = parseJsonObject(body) ?: return null
        val choices = json.optJSONArray("choices") ?: return null
        if (choices.length() == 0) return null
        val message = choices.optJSONObject(0)?.optJSONObject("message")
        return parseFlexibleContent(message?.opt("content"))
    }

    private fun parseAnthropicMessage(body: String): String? {
        val json = parseJsonObject(body) ?: return null
        return parseFlexibleContent(json.opt("content"))
    }

    private fun parseGeminiMessage(body: String): String? {
        val json = parseJsonObject(body) ?: return null
        val candidates = json.optJSONArray("candidates") ?: return null
        if (candidates.length() == 0) return null
        val content = candidates.optJSONObject(0)?.optJSONObject("content")?.optJSONArray("parts")
        return parseFlexibleContent(content)
    }

    private fun parseFlexibleContent(content: Any?): String? {
        return when (content) {
            is String -> content.trim().ifBlank { null }
            is JSONArray -> buildString {
                for (index in 0 until content.length()) {
                    val part = content.opt(index)
                    when (part) {
                        is String -> if (part.isNotBlank()) { if (isNotEmpty()) append('\n'); append(part.trim()) }
                        is JSONObject -> {
                            val text = part.optString("text").trim()
                            if (text.isNotEmpty()) { if (isNotEmpty()) append('\n'); append(text) }
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
            json.optJSONObject("error")?.optString("message")?.trim()?.let { if (it.isNotEmpty()) return it }
            json.optString("message").trim().let { if (it.isNotEmpty()) return it }
            json.optString("status").trim().let { if (it.isNotEmpty()) return it }
        }
        return body.trim().take(240).ifBlank { "$fallback ($statusCode)" }
    }

    private fun parseJsonObject(raw: String?): JSONObject? {
        if (raw.isNullOrBlank()) return null
        return try { JSONObject(raw) } catch (_: Exception) { null }
    }

    private fun finishWithSuccess(message: String) {
        mainHandler.post {
            updateState(ImeState.Success(message))
            mainHandler.postDelayed({ reset() }, 3000)
        }
    }

    private fun finishWithError(message: String) {
        mainHandler.post {
            updateState(ImeState.Error(message))
            mainHandler.postDelayed({ reset() }, 4500)
        }
    }

    private fun updateState(newState: ImeState) {
        this.state = newState
        listener?.onStateChanged(newState)
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

    private fun Request.withAuth(config: ProviderConfig): Request {
        return withAuth(config.authType, config.authHeader, config.authPrefix, config.authQueryParam, config.apiKey)
    }

    private fun Request.withAuth(config: LLMConfig): Request {
        return withAuth(config.authType, config.authHeader, config.authPrefix, config.authQueryParam, config.apiKey)
    }

    private fun Request.withAuth(
        authType: String,
        authHeader: String,
        authPrefix: String,
        authQueryParam: String,
        apiKey: String,
    ): Request {
        if (apiKey.isBlank()) return this
        return when (authType) {
            "header", "bearer" -> {
                if (authHeader.isNotBlank()) {
                    this.newBuilder().header(authHeader, "$authPrefix$apiKey").build()
                } else this
            }
            "query" -> {
                if (authQueryParam.isNotBlank()) {
                    val newUrl = this.url.newBuilder().addQueryParameter(authQueryParam, apiKey).build()
                    this.newBuilder().url(newUrl).build()
                } else this
            }
            else -> this
        }
    }
}
