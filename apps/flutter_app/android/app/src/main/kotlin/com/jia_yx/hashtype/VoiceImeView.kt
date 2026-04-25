package com.jia_yx.hashtype

import android.content.Context
import android.content.res.ColorStateList
import android.graphics.Color
import com.google.android.material.color.MaterialColors
import android.view.ContextThemeWrapper
import android.view.Gravity
import android.view.View
import android.view.ViewGroup
import android.view.animation.Animation
import android.view.animation.ScaleAnimation
import android.widget.ImageButton
import android.widget.LinearLayout
import com.google.android.material.button.MaterialButton
import com.google.android.material.shape.CornerFamily
import com.google.android.material.textview.MaterialTextView

class VoiceImeView(context: Context) : LinearLayout(context) {

    private val tvStatus: MaterialTextView
    private val btnMic: MaterialButton
    private val btnBack: ImageButton
    private val density = resources.displayMetrics.density

    init {
        orientation = VERTICAL
        // Use Dynamic Surface color for a "solid and neutral" background
        val backgroundColor = MaterialColors.getColor(this, com.google.android.material.R.attr.colorSurfaceContainer, Color.parseColor("#1F1F1F"))
        setBackgroundColor(backgroundColor)
        gravity = Gravity.CENTER_HORIZONTAL
        
        val keyboardHeight = (280 * density).toInt()
        // Note: LayoutParams for the view itself are managed by the parent (SoftInputWindow)
        // But we set them here for consistency if used in other contexts.
        layoutParams = ViewGroup.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, keyboardHeight)
        minimumHeight = keyboardHeight

        // Header Row for Back button and Status
        val header = LinearLayout(getContext()).apply {
            orientation = HORIZONTAL
            gravity = Gravity.CENTER_VERTICAL
            layoutParams = LayoutParams(LayoutParams.MATCH_PARENT, LayoutParams.WRAP_CONTENT)
            setPadding((12 * density).toInt(), (8 * density).toInt(), (12 * density).toInt(), 0)
        }

        btnBack = ImageButton(getContext()).apply {
            setImageResource(android.R.drawable.ic_menu_revert)
            background = null // Transparent background
            contentDescription = "Switch back to previous keyboard"
            val iconColor = MaterialColors.getColor(this, com.google.android.material.R.attr.colorOnSurfaceVariant, Color.parseColor("#E6E1E5"))
            imageTintList = ColorStateList.valueOf(iconColor)
            // Padding to make it easier to hit
            setPadding((12 * density).toInt(), (12 * density).toInt(), (12 * density).toInt(), (12 * density).toInt())
        }

        tvStatus = MaterialTextView(getContext()).apply {
            text = "Ready to record"
            setTextAppearance(com.google.android.material.R.style.TextAppearance_Material3_TitleMedium)
            val textColor = MaterialColors.getColor(this, com.google.android.material.R.attr.colorOnSurface, Color.parseColor("#E6E1E5"))
            setTextColor(textColor)
            gravity = Gravity.CENTER
            layoutParams = LayoutParams(0, LayoutParams.WRAP_CONTENT, 1f)
        }
        
        // Spacer for symmetry if needed, or just let text expand
        val endSpacer = View(getContext()).apply {
            layoutParams = LayoutParams((48 * density).toInt(), (48 * density).toInt())
        }

        header.addView(btnBack)
        header.addView(tvStatus)
        header.addView(endSpacer)

        // Mic Button Container (to center it vertically in remaining space)
        val micContainer = LinearLayout(getContext()).apply {
            orientation = VERTICAL
            gravity = Gravity.CENTER
            layoutParams = LayoutParams(LayoutParams.MATCH_PARENT, 0, 1f)
        }

        btnMic = MaterialButton(getContext()).apply {
            icon = androidx.core.content.ContextCompat.getDrawable(context, android.R.drawable.ic_btn_speak_now)
            iconSize = (48 * density).toInt()
            iconGravity = MaterialButton.ICON_GRAVITY_TEXT_START
            iconPadding = 0
            setPadding(0, 0, 0, 0)
            
            val btnSize = (96 * density).toInt()
            layoutParams = LayoutParams(btnSize, btnSize)
            
            // Make it circular
            shapeAppearanceModel = shapeAppearanceModel.toBuilder()
                .setAllCorners(CornerFamily.ROUNDED, btnSize / 2f)
                .build()
            
            insetTop = 0
            insetBottom = 0
            
            // Set initial color (Material 3 Primary)
            val primaryColor = MaterialColors.getColor(this, com.google.android.material.R.attr.colorPrimary, Color.parseColor("#D0BCFF"))
            backgroundTintList = ColorStateList.valueOf(primaryColor)
            elevation = 0f // Flat look for keyboard
        }

        micContainer.addView(btnMic)

        addView(header)
        addView(micContainer)
        
        // Add bottom padding
        setPadding(0, 0, 0, (16 * density).toInt())
    }

    fun setOnMicClickListener(listener: OnClickListener) {
        btnMic.setOnClickListener(listener)
    }

    fun setOnBackClickListener(listener: OnClickListener) {
        btnBack.setOnClickListener(listener)
    }

    fun updateStatus(message: String) {
        tvStatus.text = message
    }

    fun onStateChanged(state: VoiceImeViewModel.ImeState) {
        val color =
                when (state) {
                    is VoiceImeViewModel.ImeState.Recording ->
                        MaterialColors.getColor(this, com.google.android.material.R.attr.colorError, Color.parseColor("#F2B8B5"))
                    is VoiceImeViewModel.ImeState.Processing -> 
                        MaterialColors.getColor(this, com.google.android.material.R.attr.colorTertiary, Color.parseColor("#FFD166"))
                    is VoiceImeViewModel.ImeState.Success -> 
                        Color.parseColor("#B4E197") // Keep success green or use a primary container
                    is VoiceImeViewModel.ImeState.Error -> 
                        MaterialColors.getColor(this, com.google.android.material.R.attr.colorOnSurfaceVariant, Color.parseColor("#938F99"))
                    else -> 
                        MaterialColors.getColor(this, com.google.android.material.R.attr.colorPrimary, Color.parseColor("#D0BCFF"))
                }

        btnMic.backgroundTintList = ColorStateList.valueOf(color)

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
        val pulse =
                ScaleAnimation(
                                1f,
                                1.12f,
                                1f,
                                1.12f,
                                Animation.RELATIVE_TO_SELF,
                                0.5f,
                                Animation.RELATIVE_TO_SELF,
                                0.5f
                        )
                        .apply {
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
