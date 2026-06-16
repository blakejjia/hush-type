package com.jia_yx.hashtype

import android.content.Context
import android.content.Intent
import android.provider.Settings
import android.view.inputmethod.InputMethodManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

import android.graphics.Color
import com.google.android.material.color.DynamicColors
import com.google.android.material.color.MaterialColors

class MainActivity: FlutterActivity() {
    private val CHANNEL = "com.jia_yx.hashtype/ime"

    companion object {
        @Volatile
        private var instance: MainActivity? = null
        private var channel: MethodChannel? = null

        fun notifyFloatingMicStateChanged() {
            instance?.runOnUiThread {
                channel?.invokeMethod("floatingMicStateChanged", null)
            }
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        instance = this
        val methodChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
        channel = methodChannel
        methodChannel.setMethodCallHandler { call, result ->
            when (call.method) {
                "getSystemThemeColors" -> {
                    try {
                        val themedContext = DynamicColors.wrapContextIfAvailable(
                            this,
                            com.google.android.material.R.style.Theme_Material3_DayNight_NoActionBar
                        )
                        val secondaryContainer = MaterialColors.getColor(
                            themedContext,
                            com.google.android.material.R.attr.colorSecondaryContainer,
                            Color.parseColor("#E8DEF8")
                        )
                        val onSecondaryContainer = MaterialColors.getColor(
                            themedContext,
                            com.google.android.material.R.attr.colorOnSecondaryContainer,
                            Color.parseColor("#21005D")
                        )
                        val errorContainer = MaterialColors.getColor(
                            themedContext,
                            com.google.android.material.R.attr.colorErrorContainer,
                            Color.parseColor("#F9DEDC")
                        )
                        val onErrorContainer = MaterialColors.getColor(
                            themedContext,
                            com.google.android.material.R.attr.colorOnErrorContainer,
                            Color.parseColor("#410E0B")
                        )

                        val colorsMap = mapOf(
                            "colorSecondaryContainer" to String.format("#%06X", 0xFFFFFF and secondaryContainer),
                            "colorOnSecondaryContainer" to String.format("#%06X", 0xFFFFFF and onSecondaryContainer),
                            "colorErrorContainer" to String.format("#%06X", 0xFFFFFF and errorContainer),
                            "colorOnErrorContainer" to String.format("#%06X", 0xFFFFFF and onErrorContainer)
                        )
                        result.success(colorsMap)
                    } catch (e: Exception) {
                        result.error("COLOR_ERROR", e.message, null)
                    }
                }
                "openIMESettings" -> {
                    val intent = Intent(Settings.ACTION_INPUT_METHOD_SETTINGS)
                    intent.flags = Intent.FLAG_ACTIVITY_NEW_TASK
                    startActivity(intent)
                    result.success(true)
                }
                "isIMEEnabled" -> {
                    val imm = getSystemService(Context.INPUT_METHOD_SERVICE) as InputMethodManager
                    val enabledInputMethodIds = imm.enabledInputMethodList.map { it.id }
                    // The ID is usually "packageName/.ServiceName"
                    val myImeId = "${context.packageName}/.VoiceInputMethodService"
                    result.success(enabledInputMethodIds.contains(myImeId))
                }
                "isOverlayPermissionGranted" -> {
                    result.success(Settings.canDrawOverlays(this))
                }
                "requestOverlayPermission" -> {
                    val intent = Intent(Settings.ACTION_MANAGE_OVERLAY_PERMISSION)
                    intent.data = android.net.Uri.parse("package:$packageName")
                    intent.flags = Intent.FLAG_ACTIVITY_NEW_TASK
                    startActivity(intent)
                    result.success(true)
                }
                "isAccessibilityServiceEnabled" -> {
                    val expected = "$packageName/${HashtypeFloatingService::class.java.canonicalName}"
                    val settingValue = Settings.Secure.getString(
                        contentResolver,
                        Settings.Secure.ENABLED_ACCESSIBILITY_SERVICES
                    )
                    result.success(settingValue?.contains(expected) == true)
                }
                "openAccessibilitySettings" -> {
                    val intent = Intent(Settings.ACTION_ACCESSIBILITY_SETTINGS)
                    intent.flags = Intent.FLAG_ACTIVITY_NEW_TASK
                    startActivity(intent)
                    result.success(true)
                }
                "updateFloatingMicSettings" -> {
                    HashtypeFloatingService.updateSettings()
                    result.success(true)
                }
                "getHistory" -> {
                    val limit = call.argument<Int>("limit") ?: 100
                    val offset = call.argument<Int>("offset") ?: 0
                    val db = HistoryDbHelper.getInstance(this)
                    val records = db.getRecords(limit, offset)
                    result.success(records)
                }
                "deleteHistoryItem" -> {
                    val id = call.argument<Int>("id") ?: -1
                    val db = HistoryDbHelper.getInstance(this)
                    val count = db.deleteRecord(id)
                    result.success(count > 0)
                }
                "clearHistory" -> {
                    val db = HistoryDbHelper.getInstance(this)
                    db.clearAllRecords()
                    result.success(true)
                }
                "searchHistory" -> {
                    val query = call.argument<String>("query") ?: ""
                    val db = HistoryDbHelper.getInstance(this)
                    val records = db.searchRecords(query)
                    result.success(records)
                }
                else -> {
                    result.notImplemented()
                }
            }
        }
    }

    override fun onDestroy() {
        if (instance == this) {
            instance = null
            channel = null
        }
        super.onDestroy()
    }
}
