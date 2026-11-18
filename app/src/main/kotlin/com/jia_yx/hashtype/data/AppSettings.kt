package com.jia_yx.hashtype.data

import android.content.Context
import android.content.SharedPreferences
import org.json.JSONArray
import org.json.JSONObject

data class LanguageItem(
    val name: String,
    val code: String
)

object AppSettings {
    private const val PREFS_NAME = "FlutterSharedPreferences"

    private const val KEY_FLOATING_MIC_ENABLED = "flutter.floating_mic_enabled"
    private const val KEY_FLOATING_MIC_SIZE = "flutter.floating_mic_size"
    private const val KEY_FLOATING_MIC_COLOR = "flutter.floating_mic_color"
    private const val KEY_FLOATING_MIC_ICON = "flutter.floating_mic_icon"
    private const val KEY_SELECTED_LANGUAGES = "flutter.selected_languages"
    private const val KEY_STT_SETTINGS = "flutter.stt_settings"
    private const val KEY_LLM_SETTINGS = "flutter.llm_settings"

    val AVAILABLE_LANGUAGES = listOf(
        LanguageItem("English (US)", "en_US"),
        LanguageItem("Chinese (Simplified)", "zh_CN"),
        LanguageItem("Chinese (Traditional)", "zh_TW"),
        LanguageItem("Spanish", "es_ES"),
        LanguageItem("French", "fr_FR"),
        LanguageItem("German", "de_DE"),
        LanguageItem("Japanese", "ja_JP"),
        LanguageItem("Korean", "ko_KR"),
        LanguageItem("Russian", "ru_RU"),
        LanguageItem("Portuguese", "pt_PT")
    )

    private fun getPrefs(context: Context): SharedPreferences {
        return context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
    }

    // Floating Mic Settings
    fun isFloatingMicEnabled(context: Context): Boolean = true

    fun setFloatingMicEnabled(context: Context, enabled: Boolean) {
        getPrefs(context).edit().putBoolean(KEY_FLOATING_MIC_ENABLED, true).apply()
    }

    fun getFloatingMicSize(context: Context): String {
        return getPrefs(context).getString(KEY_FLOATING_MIC_SIZE, "medium") ?: "medium"
    }

    fun setFloatingMicSize(context: Context, size: String) {
        getPrefs(context).edit().putString(KEY_FLOATING_MIC_SIZE, size).apply()
    }

    fun getFloatingMicColor(context: Context): String = "theme"

    fun setFloatingMicColor(context: Context, color: String) {
        getPrefs(context).edit().putString(KEY_FLOATING_MIC_COLOR, "theme").apply()
    }

    fun getFloatingMicIcon(context: Context): String {
        return getPrefs(context).getString(KEY_FLOATING_MIC_ICON, "mic") ?: "mic"
    }

    fun setFloatingMicIcon(context: Context, icon: String) {
        getPrefs(context).edit().putString(KEY_FLOATING_MIC_ICON, icon).apply()
    }

    // Language Settings
    fun getSelectedLanguages(context: Context): List<String> {
        val raw = getPrefs(context).getString(KEY_SELECTED_LANGUAGES, null) ?: return listOf("en_US")
        return try {
            val jsonArray = JSONArray(raw)
            val list = mutableListOf<String>()
            for (i in 0 until jsonArray.length()) {
                list.add(jsonArray.getString(i))
            }
            if (list.isEmpty()) listOf("en_US") else list
        } catch (_: Exception) {
            listOf("en_US")
        }
    }

    fun setSelectedLanguages(context: Context, languages: List<String>) {
        val jsonArray = JSONArray(languages)
        getPrefs(context).edit().putString(KEY_SELECTED_LANGUAGES, jsonArray.toString()).apply()
    }

    fun getSelectedLanguageNames(context: Context): String {
        val selected = getSelectedLanguages(context)
        return selected.map { code ->
            AVAILABLE_LANGUAGES.find { it.code == code }?.name ?: code
        }.joinToString(", ")
    }

    // STT Settings
    fun getSttSettingsJson(context: Context): JSONObject {
        val raw = getPrefs(context).getString(KEY_STT_SETTINGS, null)
        return if (!raw.isNullOrBlank()) {
            try { JSONObject(raw) } catch (_: Exception) { JSONObject() }
        } else {
            JSONObject()
        }
    }

    fun saveSttSettingsJson(context: Context, json: JSONObject) {
        getPrefs(context).edit().putString(KEY_STT_SETTINGS, json.toString()).apply()
    }

    // LLM Settings
    fun getLlmSettingsJson(context: Context): JSONObject {
        val raw = getPrefs(context).getString(KEY_LLM_SETTINGS, null)
        return if (!raw.isNullOrBlank()) {
            try { JSONObject(raw) } catch (_: Exception) { JSONObject() }
        } else {
            JSONObject()
        }
    }

    fun saveLlmSettingsJson(context: Context, json: JSONObject) {
        getPrefs(context).edit().putString(KEY_LLM_SETTINGS, json.toString()).apply()
    }
}
