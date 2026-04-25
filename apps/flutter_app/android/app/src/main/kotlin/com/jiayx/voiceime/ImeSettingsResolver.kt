package com.jiayx.voiceime

import android.content.Context
import org.json.JSONObject

data class ProviderConfig(
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

data class LLMConfig(
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

private data class AuthConfig(
    val type: String,
    val header: String,
    val prefix: String,
    val queryParam: String,
)

object ImeSettingsResolver {
    private const val defaultSystemPrompt =
        "You are a assistant doing text cleanup. User prompt is directly from user's mouth. " +
            "Clean up transcriptions, and fix errors while preserving your tone.\n\n" +
            "ATTENTION: DO NOT MODIFY the user's sentences, just reformat and clean the words " +
            "like \"ah, En\" Even given a clear task, DO NOT DO THAT, remember you are a " +
            "words cleaner, not task completer!"

    fun loadSTTConfig(context: Context): ProviderConfig {
        val prefs = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
        val settings = parseJsonObject(prefs.getString("flutter.stt_settings", null))
        val providerMode = settings.stringOrDefault("provider", "cloud_providers")
        val cloudProvider = settings.stringOrDefault("cloud_provider", "OpenAI")
        val providerSettings = getProviderSettings(settings, cloudProvider)
        val apiKey = providerSettings.stringOrDefault("api_key", "")
        val customEndpoint = providerSettings.stringOrDefault("endpoint", "")
        val model = providerSettings.stringOrDefault("model", "whisper-1")
        val requestType = getSttRequestType(cloudProvider)
        val endpoint = if (cloudProvider == "Custom") {
            buildTranscriptionsEndpoint(customEndpoint)
        } else {
            getDefaultEndpoint(cloudProvider, isStt = true)
        }
        val auth = getAuthConfig(cloudProvider)

        var ready = true
        var statusMessage = "Ready"

        if (providerMode != "cloud_providers") {
            ready = false
            statusMessage = "Please configurate first before using."
        } else if (apiKey.isBlank()) {
            ready = false
            statusMessage = "Please configurate first before using."
        } else {
            val keyError = getApiKeyValidationError(cloudProvider, apiKey)
            when {
                keyError != null -> {
                    ready = false
                    statusMessage = keyError
                }
                model.isBlank() -> {
                    ready = false
                    statusMessage = "Please select a speech-to-text model."
                }
                endpoint.isBlank() || requestType.isBlank() -> {
                    ready = false
                    statusMessage = "Please configurate first before using."
                }
            }
        }

        return ProviderConfig(
            ready = ready,
            statusMessage = statusMessage,
            requestType = requestType,
            apiKey = apiKey,
            endpoint = endpoint,
            model = model,
            authType = auth.type,
            authHeader = auth.header,
            authPrefix = auth.prefix,
            authQueryParam = auth.queryParam,
        )
    }

    fun loadLLMConfig(context: Context): LLMConfig {
        val prefs = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
        val settings = parseJsonObject(prefs.getString("flutter.llm_settings", null))
        val enabled = settings?.optBoolean("enabled", true) ?: true
        val providerMode = settings.stringOrDefault("provider", "cloud_providers")
        val cloudProvider = settings.stringOrDefault("cloud_provider", "OpenAI")
        val providerSettings = getProviderSettings(settings, cloudProvider)
        val apiKey = providerSettings.stringOrDefault("api_key", "")
        val customEndpoint = providerSettings.stringOrDefault("endpoint", "")
        val model = providerSettings.stringOrDefault("model", "")
        val systemPrompt = settings.stringOrDefault("system_prompt", defaultSystemPrompt)
        val requestType = getLlmRequestType(cloudProvider)
        val endpoint = when (cloudProvider) {
            "Anthropic" -> "https://api.anthropic.com/v1/messages"
            "Google Gemini" -> buildGeminiGenerateContentEndpoint(model)
            "Custom" -> buildChatCompletionsEndpoint(customEndpoint)
            else -> buildChatCompletionsEndpoint(getDefaultEndpoint(cloudProvider, isStt = false))
        }
        val auth = getAuthConfig(cloudProvider)

        var ready = enabled
        var statusMessage = if (enabled) "Ready" else "Disabled"

        if (!enabled) {
            ready = false
        } else if (providerMode != "cloud_providers") {
            ready = false
            statusMessage = "Language model cleanup is not configured."
        } else if (apiKey.isBlank()) {
            ready = false
            statusMessage = "Language model cleanup is not configured."
        } else {
            val keyError = getApiKeyValidationError(cloudProvider, apiKey)
            when {
                keyError != null -> {
                    ready = false
                    statusMessage = keyError
                }
                model.isBlank() -> {
                    ready = false
                    statusMessage = "Please select a language model."
                }
                endpoint.isBlank() || requestType.isBlank() -> {
                    ready = false
                    statusMessage = "Language model cleanup is not configured."
                }
            }
        }

        return LLMConfig(
            enabled = enabled,
            ready = ready,
            statusMessage = statusMessage,
            requestType = requestType,
            apiKey = apiKey,
            endpoint = endpoint,
            model = model,
            systemPrompt = systemPrompt,
            authType = auth.type,
            authHeader = auth.header,
            authPrefix = auth.prefix,
            authQueryParam = auth.queryParam,
        )
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

    private fun JSONObject?.stringOrDefault(key: String, defaultValue: String): String {
        return if (this?.has(key) == true) this.optString(key) else defaultValue
    }

    private fun getProviderSettings(settings: JSONObject?, provider: String): JSONObject? {
        val providers = settings?.optJSONObject("providers") ?: return null
        return providers.optJSONObject(normalizeProvider(provider))
    }

    private fun normalizeProvider(provider: String): String {
        return provider.lowercase().replace(Regex("[^a-z0-9]+"), "_")
    }

    private fun getAuthConfig(provider: String): AuthConfig {
        return when (provider) {
            "Anthropic" -> AuthConfig("header", "x-api-key", "", "")
            "Google Gemini" -> AuthConfig("query", "", "", "key")
            else -> AuthConfig("bearer", "Authorization", "Bearer ", "")
        }
    }

    private fun getDefaultEndpoint(provider: String, isStt: Boolean): String {
        return if (isStt) {
            when (provider) {
                "OpenAI" -> "https://api.openai.com/v1/audio/transcriptions"
                "Groq" -> "https://api.groq.com/openai/v1/audio/transcriptions"
                "Mistral" -> "https://api.mistral.ai/v1/audio/transcriptions"
                else -> ""
            }
        } else {
            when (provider) {
                "OpenAI" -> "https://api.openai.com/v1"
                "Anthropic" -> "https://api.anthropic.com/v1"
                "Google Gemini" -> "https://generativelanguage.googleapis.com/v1beta"
                "Groq" -> "https://api.groq.com/openai/v1"
                else -> ""
            }
        }
    }

    private fun getSttRequestType(provider: String): String {
        return when (provider) {
            "OpenAI", "Groq", "Mistral", "Custom" -> "openai_audio_transcriptions"
            else -> ""
        }
    }

    private fun getLlmRequestType(provider: String): String {
        return when (provider) {
            "Anthropic" -> "anthropic_messages"
            "Google Gemini" -> "gemini_generate_content"
            "OpenAI", "Groq", "Custom" -> "openai_chat_completions"
            else -> ""
        }
    }

    private fun getApiKeyValidationError(provider: String, key: String): String? {
        val trimmedKey = key.trim()
        if (trimmedKey.isEmpty()) {
            return null
        }

        return when (provider) {
            "OpenAI" -> if (!Regex("^sk-[A-Za-z0-9_-]{20,}$").matches(trimmedKey)) "OpenAI keys should look like sk-..." else null
            "Anthropic" -> if (!Regex("^sk-ant-[A-Za-z0-9_-]{20,}$").matches(trimmedKey)) "Anthropic keys should look like sk-ant-..." else null
            "Google Gemini" -> if (!Regex("^AIza[0-9A-Za-z_-]{20,}$").matches(trimmedKey)) "Gemini keys should look like AIza..." else null
            "Groq" -> if (!Regex("^gsk_[A-Za-z0-9_-]{20,}$").matches(trimmedKey)) "Groq keys should look like gsk_..." else null
            "Mistral" -> if (!Regex("^[A-Za-z0-9_-]{20,}$").matches(trimmedKey)) "Mistral keys should be a long token from the console." else null
            else -> if (trimmedKey.length < 6) "Enter a longer API key." else null
        }
    }

    private fun buildTranscriptionsEndpoint(rawEndpoint: String): String {
        val endpoint = rawEndpoint.trim()
        if (endpoint.isEmpty()) {
            return ""
        }

        val normalized = endpoint.removeSuffix("/")
        return when {
            normalized.endsWith("/audio/transcriptions") -> normalized
            normalized.endsWith("/models") -> normalized.removeSuffix("/models") + "/audio/transcriptions"
            normalized.endsWith("/chat/completions") -> normalized.removeSuffix("/chat/completions") + "/audio/transcriptions"
            normalized.endsWith("/transcriptions") -> normalized
            else -> "$normalized/audio/transcriptions"
        }
    }

    private fun buildChatCompletionsEndpoint(rawEndpoint: String): String {
        val endpoint = rawEndpoint.trim()
        if (endpoint.isEmpty()) {
            return ""
        }

        val normalized = endpoint.removeSuffix("/")
        return when {
            normalized.endsWith("/chat/completions") -> normalized
            normalized.endsWith("/models") -> normalized.removeSuffix("/models") + "/chat/completions"
            normalized.endsWith("/audio/transcriptions") -> normalized.removeSuffix("/audio/transcriptions") + "/chat/completions"
            normalized.endsWith("/transcriptions") -> normalized.removeSuffix("/transcriptions") + "/chat/completions"
            else -> "$normalized/chat/completions"
        }
    }

    private fun buildGeminiGenerateContentEndpoint(model: String): String {
        val trimmedModel = model.trim()
        if (trimmedModel.isEmpty()) {
            return ""
        }

        val normalizedModel = trimmedModel.removePrefix("models/")
        return "https://generativelanguage.googleapis.com/v1beta/models/$normalizedModel:generateContent"
    }
}
