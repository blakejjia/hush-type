package com.jiayx.voiceime

import android.content.Context
import android.graphics.Color
import android.view.ContextThemeWrapper
import android.view.Gravity
import android.view.animation.Animation
import android.view.animation.ScaleAnimation
import android.widget.LinearLayout
import com.google.android.material.floatingactionbutton.FloatingActionButton
import com.google.android.material.textview.MaterialTextView

class VoiceImeView(context: Context) : LinearLayout(
    ContextThemeWrapper(context, com.google.android.material.R.style.Theme_Material3_Dark_NoActionBar)
) {

    private val tvStatus: MaterialTextView
    private val btnMic: FloatingActionButton
    private val density = resources.displayMetrics.density

    init {
        orientation = VERTICAL
        // Use Material 3 Surface color if possible, otherwise keep it dark
        setBackgroundColor(Color.parseColor("#1C1B1F")) // M3 Dark Surface
        gravity = Gravity.CENTER
        val keyboardHeight = (280 * density).toInt()
        layoutParams = LayoutParams(LayoutParams.MATCH_PARENT, keyboardHeight)
        minimumHeight = keyboardHeight
        setPadding(0, 0, 0, (20 * density).toInt())

        tvStatus = MaterialTextView(getContext()).apply {
            text = "Ready to record"
            setTextAppearance(com.google.android.material.R.style.TextAppearance_Material3_TitleMedium)
            setTextColor(Color.parseColor("#E6E1E5")) // On Surface variant
            setPadding(0, 0, 0, (32 * density).toInt())
            gravity = Gravity.CENTER
        }

        btnMic = FloatingActionButton(getContext()).apply {
            setImageResource(android.R.drawable.ic_btn_speak_now)
            // Scale up the icon a bit to fit the large FAB
            val btnSize = (80 * density).toInt()
            layoutParams = LayoutParams(btnSize, btnSize).apply {
                gravity = Gravity.CENTER
            }
            // Use M3 large fab style if desired, or just custom size
            customSize = btnSize
            
            // Set initial color (Material 3 Primary)
            setBackgroundColor(Color.parseColor("#D0BCFF")) 
        }

        addView(tvStatus)
        addView(btnMic)
    }

    fun setOnMicClickListener(listener: OnClickListener) {
        btnMic.setOnClickListener(listener)
    }

    fun updateStatus(message: String) {
        tvStatus.text = message
    }

    fun onStateChanged(state: VoiceImeViewModel.ImeState) {
        val colorHex = when (state) {
            is VoiceImeViewModel.ImeState.Recording -> "#F2B8B5" // M3 Error Container (Pinkish Red)
            is VoiceImeViewModel.ImeState.Processing -> "#FFD166" // Amber-ish
            is VoiceImeViewModel.ImeState.Success -> "#B4E197" // Greenish
            is VoiceImeViewModel.ImeState.Error -> "#938F99" // Outline variant (Grey)
            else -> "#D0BCFF" // M3 Primary
        }
        
        val color = Color.parseColor(colorHex)
        btnMic.backgroundTintList = android.content.res.ColorStateList.valueOf(color)

        btnMic.isEnabled = state !is VoiceImeViewModel.ImeState.Processing
        btnMic.alpha = if (state is VoiceImeViewModel.ImeState.Error) 0.6f else 1.0f

        if (state is VoiceImeViewModel.ImeState.Recording) {
            startPulseAnimation()
        } else {
            stopPulseAnimation()
        }

        if (state is VoiceImeViewModel.ImeState.Error) {
            tvStatus.text = state.message
        } else if (state is VoiceImeViewModel.ImeState.Success) {
            tvStatus.text = state.message
        }
    }

    private fun startPulseAnimation() {
        val pulse = ScaleAnimation(
            1f, 1.12f, 1f, 1.12f,
            Animation.RELATIVE_TO_SELF, 0.5f,
            Animation.RELATIVE_TO_SELF, 0.5f
        ).apply {
            duration = 1000
            repeatMode = Animation.REVERSE
            repeatCount = Animation.INFINITE
        }
        btnMic.startAnimation(pulse)
    }

    private fun stopPulseAnimation() {
        btnMic.clearAnimation()
    }
}
