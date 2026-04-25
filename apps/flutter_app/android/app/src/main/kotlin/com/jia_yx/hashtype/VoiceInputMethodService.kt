package com.jia_yx.hashtype

import android.content.Intent
import android.inputmethodservice.InputMethodService
import android.view.View
import android.view.inputmethod.EditorInfo

class VoiceInputMethodService : InputMethodService(), VoiceImeViewModel.Listener {

    private lateinit var viewModel: VoiceImeViewModel
    private var imeView: VoiceImeView? = null

    override fun onCreate() {
        super.onCreate()
        viewModel = VoiceImeViewModel(this)
        viewModel.setListener(this)
    }

    override fun onCreateInputView(): View {
        val view = VoiceImeView(this)
        view.setOnMicClickListener {
            viewModel.handleMicClick()
        }
        imeView = view
        return view
    }

    override fun onStartInputView(info: EditorInfo?, restarting: Boolean) {
        super.onStartInputView(info, restarting)
        viewModel.reset()
    }

    override fun onComputeInsets(outInsets: Insets) {
        super.onComputeInsets(outInsets)
        if (!isFullscreenMode) {
            outInsets.contentTopInsets = outInsets.visibleTopInsets
        }
    }

    override fun onEvaluateFullscreenMode(): Boolean = false

    // ViewModel Listener methods

    override fun onStateChanged(state: VoiceImeViewModel.ImeState) {
        imeView?.onStateChanged(state)
    }

    override fun onStatusMessageChanged(message: String) {
        imeView?.updateStatus(message)
    }

    override fun onTextCommitted(text: String) {
        currentInputConnection?.commitText(text, 1)
    }

    override fun onOpenSettings() {
        val intent = Intent(this, MainActivity::class.java).apply {
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        }
        startActivity(intent)
    }
}
