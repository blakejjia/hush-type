package com.jiayx.voiceime

import android.inputmethodservice.InputMethodService
import android.view.View
import android.view.inputmethod.EditorInfo
import android.widget.Button
import android.widget.TextView

class VoiceInputMethodService : InputMethodService() {

    private lateinit var keyboardView: View
    private lateinit var btnMic: Button
    private lateinit var tvStatus: TextView
    private var isRecording = false

    override fun onCreateInputView(): View {
        // 为了 MVP 简单，这里直接用代码动态创建一个简单布局，实际项目建议 inflate XML
        val layout = android.widget.LinearLayout(this).apply {
            orientation = android.widget.LinearLayout.VERTICAL
            setBackgroundColor(android.graphics.Color.DKGRAY)
            setPadding(32, 32, 32, 32)
        }

        tvStatus = TextView(this).apply {
            text = "Ready to record"
            setTextColor(android.graphics.Color.WHITE)
            textSize = 16f
        }

        btnMic = Button(this).apply {
            text = "Hold to Talk"
            setOnClickListener { toggleRecording() }
        }

        layout.addView(tvStatus)
        layout.addView(btnMic)
        keyboardView = layout
        return keyboardView
    }

    override fun onStartInputView(info: EditorInfo?, restarting: Boolean) {
        super.onStartInputView(info, restarting)
        // 每次键盘弹出重置状态
        tvStatus.text = "Ready to record"
    }

    private fun toggleRecording() {
        if (isRecording) {
            stopRecordingAndTranscribe()
        } else {
            startRecording()
        }
    }

    private fun startRecording() {
        // TODO: 1. 检查 RECORD_AUDIO 权限 (如果没有，提示用户打开主 App 授权)
        // TODO: 2. 初始化 MediaRecorder
        isRecording = true
        btnMic.text = "Stop & Send"
        tvStatus.text = "Listening..."
    }

    private fun stopRecordingAndTranscribe() {
        // TODO: 1. 停止 MediaRecorder
        isRecording = false
        btnMic.text = "Hold to Talk"
        tvStatus.text = "Transcribing..."

        // TODO: 2. 读取 SharedPreferences 获取 Firebase Token
        // TODO: 3. 上传文件到 Firebase Function

        // Mock 网络回调成功后写入文本
        mockNetworkCall { transcribedText ->
            commitTextToInput(transcribedText)
            tvStatus.text = "Success!"
        }
    }

    private fun commitTextToInput(text: String) {
        val ic = currentInputConnection
        ic?.commitText(text, 1)
    }

    private fun mockNetworkCall(callback: (String) -> Unit) {
        android.os.Handler(android.os.Looper.getMainLooper()).postDelayed({
            callback("Hello, this is a transcribed text.")
        }, 1500)
    }
}