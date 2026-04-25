package com.jia_yx.hashtype

import android.content.Intent
import android.inputmethodservice.InputMethodService
import android.view.View
import android.view.inputmethod.EditorInfo
import com.google.android.material.color.DynamicColors

class VoiceInputMethodService : InputMethodService(), VoiceImeViewModel.Listener {
    private lateinit var viewModel: VoiceImeViewModel
    private var imeView: VoiceImeView? = null

    override fun onCreate() {
        super.onCreate()
        viewModel = VoiceImeViewModel(this)
        viewModel.setListener(this)
    }

    override fun onCreateInputView(): View {
        val themedContext = DynamicColors.wrapContextIfAvailable(this, com.google.android.material.R.style.Theme_Material3_DayNight_NoActionBar)
        val view = VoiceImeView(themedContext)
        view.setOnMicClickListener {
            viewModel.handleMicClick()
        }
        view.setOnBackClickListener {
            switchToPreviousKeyboard()
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

    private fun switchToPreviousKeyboard() {
        try {
            if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.P) {
                switchToPreviousInputMethod()
            } else {
                val imm = getSystemService(INPUT_METHOD_SERVICE) as android.view.inputmethod.InputMethodManager
                imm.switchToLastInputMethod(window?.window?.attributes?.token)
            }
        } catch (e: Exception) {
            // Fallback or log error
            if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.M) {
                shouldOfferSwitchingToNextInputMethod()
            }
        }
    }
}
