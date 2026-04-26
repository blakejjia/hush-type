package com.jia_yx.hashtype

import android.content.Intent
import android.os.Bundle
import android.speech.RecognitionService
import android.speech.SpeechRecognizer
import android.util.Log

class HashtypeRecognitionService : RecognitionService(), VoiceImeViewModel.Listener {

    private lateinit var viewModel: VoiceImeViewModel
    private var recognitionCallback: Callback? = null

    override fun onCreate() {
        super.onCreate()
        viewModel = VoiceImeViewModel(this)
        viewModel.setListener(this)
    }

    override fun onStartListening(intent: Intent?, listener: Callback?) {
        recognitionCallback = listener
        try {
            recognitionCallback?.readyForSpeech(Bundle())
        } catch (e: Exception) {
            Log.e("HashtypeRecService", "Error calling readyForSpeech", e)
        }
        viewModel.startRecording()
    }

    override fun onStopListening(listener: Callback?) {
        viewModel.stopRecordingAndTranscribe()
    }

    override fun onCancel(listener: Callback?) {
        viewModel.cancelRecording()
    }

    // VoiceImeViewModel.Listener implementation

    override fun onStateChanged(state: VoiceImeViewModel.ImeState) {
        when (state) {
            is VoiceImeViewModel.ImeState.Error -> {
                try {
                    recognitionCallback?.error(SpeechRecognizer.ERROR_CLIENT)
                } catch (e: Exception) {
                    Log.e("HashtypeRecService", "Error calling callback error", e)
                }
            }
            is VoiceImeViewModel.ImeState.Processing -> {
                try {
                    recognitionCallback?.endOfSpeech()
                } catch (e: Exception) {
                    Log.e("HashtypeRecService", "Error calling endOfSpeech", e)
                }
            }
            else -> {}
        }
    }

    override fun onStatusMessageChanged(message: String) {
        // Not used for STT service
    }

    override fun onTextCommitted(text: String) {
        try {
            val bundle = Bundle().apply {
                putStringArrayList(SpeechRecognizer.RESULTS_RECOGNITION, arrayListOf(text))
            }
            recognitionCallback?.results(bundle)
        } catch (e: Exception) {
            Log.e("HashtypeRecService", "Error returning results", e)
        }
    }

    override fun onBackspace() {
        // Not used for STT service
    }

    override fun onEnter() {
        // Not used for STT service
    }

    override fun onOpenSettings() {
        // Not used for STT service
    }
}

