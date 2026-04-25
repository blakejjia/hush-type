package com.jiayx.voiceime

import android.content.Context
import android.content.Intent
import android.provider.Settings
import android.view.inputmethod.InputMethodManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity: FlutterActivity() {
    private val CHANNEL = "com.jiayx.voiceime/ime"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
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
                else -> {
                    result.notImplemented()
                }
            }
        }
    }
}
