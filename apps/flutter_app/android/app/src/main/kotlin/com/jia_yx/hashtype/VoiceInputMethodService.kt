package com.jia_yx.hashtype

import android.content.Intent
import android.inputmethodservice.InputMethodService
import android.view.KeyEvent
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
        view.setOnBackspaceClickListener {
            viewModel.handleBackspace()
        }
        view.setOnEnterClickListener {
            viewModel.handleEnter()
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

    override fun onBackspace() {
        val ic = currentInputConnection ?: return
        ic.sendKeyEvent(KeyEvent(KeyEvent.ACTION_DOWN, KeyEvent.KEYCODE_DEL))
        ic.sendKeyEvent(KeyEvent(KeyEvent.ACTION_UP, KeyEvent.KEYCODE_DEL))
    }

    override fun onEnter() {
        val ic = currentInputConnection ?: return
        // Try to send the default editor action (like Search, Go, Done)
        // If that's not handled, it often falls back to newline or just does nothing
        val editorInfo = currentInputEditorInfo
        if (editorInfo != null && (editorInfo.imeOptions and EditorInfo.IME_MASK_ACTION) != EditorInfo.IME_ACTION_NONE) {
            ic.performEditorAction(editorInfo.imeOptions and EditorInfo.IME_MASK_ACTION)
        } else {
            // Fallback to sending a literal newline or ENTER key event
            ic.sendKeyEvent(KeyEvent(KeyEvent.ACTION_DOWN, KeyEvent.KEYCODE_ENTER))
            ic.sendKeyEvent(KeyEvent(KeyEvent.ACTION_UP, KeyEvent.KEYCODE_ENTER))
        }
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
