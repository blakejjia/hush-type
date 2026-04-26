package com.jia_yx.hashtype

import android.content.Context
import android.content.res.ColorStateList
import android.graphics.Color
import com.google.android.material.color.MaterialColors
import android.view.Gravity
import android.view.HapticFeedbackConstants
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
    private val btnBackspace: MaterialButton
    private val btnEnter: MaterialButton
    private val btnBack: ImageButton
    private val density = resources.displayMetrics.density

    init {
        orientation = VERTICAL
        // Use Dynamic Surface color for a "solid and neutral" background
        val backgroundColor = MaterialColors.getColor(this, com.google.android.material.R.attr.colorSurfaceContainer, Color.parseColor("#1F1F1F"))
        setBackgroundColor(backgroundColor)
        gravity = Gravity.CENTER_HORIZONTAL
        
        val keyboardHeight = (280 * density).toInt()
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
            setPadding((12 * density).toInt(), (12 * density).toInt(), (12 * density).toInt(), (12 * density).toInt())
            setOnClickListener {
                vibrate()
            }
        }

        tvStatus = MaterialTextView(getContext()).apply {
            text = "Ready to record"
            setTextAppearance(com.google.android.material.R.style.TextAppearance_Material3_TitleMedium)
            val textColor = MaterialColors.getColor(this, com.google.android.material.R.attr.colorOnSurface, Color.parseColor("#E6E1E5"))
            setTextColor(textColor)
            gravity = Gravity.CENTER
            layoutParams = LayoutParams(0, LayoutParams.WRAP_CONTENT, 1f)
        }
        
        val endSpacer = View(getContext()).apply {
            layoutParams = LayoutParams((48 * density).toInt(), (48 * density).toInt())
        }

        header.addView(btnBack)
        header.addView(tvStatus)
        header.addView(endSpacer)

        // Horizontal container for Mic and Right controls
        val controlRow = LinearLayout(getContext()).apply {
            orientation = HORIZONTAL
            gravity = Gravity.CENTER_VERTICAL
            layoutParams = LayoutParams(LayoutParams.MATCH_PARENT, 0, 1f)
            setPadding((16 * density).toInt(), 0, (16 * density).toInt(), 0)
        }

        val leftSpacer = View(getContext()).apply {
            layoutParams = LayoutParams(0, 0, 1f)
        }

        val secondaryBtnSize = (56 * density).toInt()
        val onControlBtnColor = MaterialColors.getColor(this, com.google.android.material.R.attr.colorOnSurfaceVariant, Color.parseColor("#E6E1E5"))

        btnBackspace = MaterialButton(context, null, com.google.android.material.R.attr.materialButtonOutlinedStyle).apply {
            icon = androidx.core.content.ContextCompat.getDrawable(context, R.drawable.ic_backspace_m3)
            iconGravity = MaterialButton.ICON_GRAVITY_TEXT_START
            iconPadding = 0
            iconTint = ColorStateList.valueOf(onControlBtnColor)
            setPadding(0, 0, 0, 0)
            layoutParams = LayoutParams(secondaryBtnSize, secondaryBtnSize).apply {
                bottomMargin = (12 * density).toInt()
            }
            shapeAppearanceModel = shapeAppearanceModel.toBuilder()
                .setAllCorners(CornerFamily.ROUNDED, secondaryBtnSize / 2f)
                .build()
            strokeColor = ColorStateList.valueOf(onControlBtnColor)
            elevation = 0f
            insetTop = 0
            insetBottom = 0
        }

        btnMic = MaterialButton(getContext()).apply {
            icon = androidx.core.content.ContextCompat.getDrawable(context, android.R.drawable.ic_btn_speak_now)
            iconSize = (48 * density).toInt()
            iconGravity = MaterialButton.ICON_GRAVITY_TEXT_START
            iconPadding = 0
            setPadding(0, 0, 0, 0)
            
            val btnSize = (96 * density).toInt()
            layoutParams = LayoutParams(btnSize, btnSize)
            
            shapeAppearanceModel = shapeAppearanceModel.toBuilder()
                .setAllCorners(CornerFamily.ROUNDED, btnSize / 2f)
                .build()
            
            insetTop = 0
            insetBottom = 0
            
            val primaryColor = MaterialColors.getColor(this, com.google.android.material.R.attr.colorPrimary, Color.parseColor("#D0BCFF"))
            backgroundTintList = ColorStateList.valueOf(primaryColor)
            elevation = 0f
        }

        btnEnter = MaterialButton(context, null, com.google.android.material.R.attr.materialButtonOutlinedStyle).apply {
            icon = androidx.core.content.ContextCompat.getDrawable(context, R.drawable.ic_keyboard_return_m3)
            iconGravity = MaterialButton.ICON_GRAVITY_TEXT_START
            iconPadding = 0
            iconTint = ColorStateList.valueOf(onControlBtnColor)
            setPadding(0, 0, 0, 0)
            layoutParams = LayoutParams(secondaryBtnSize, secondaryBtnSize)
            shapeAppearanceModel = shapeAppearanceModel.toBuilder()
                .setAllCorners(CornerFamily.ROUNDED, secondaryBtnSize / 2f)
                .build()
            strokeColor = ColorStateList.valueOf(onControlBtnColor)
            elevation = 0f
            insetTop = 0
            insetBottom = 0
        }

        val rightControls = LinearLayout(getContext()).apply {
            orientation = VERTICAL
            gravity = Gravity.CENTER_HORIZONTAL
            layoutParams = LayoutParams(0, LayoutParams.WRAP_CONTENT, 1f)
            addView(btnBackspace)
            addView(btnEnter)
        }

        controlRow.addView(leftSpacer)
        controlRow.addView(btnMic)
        controlRow.addView(rightControls)

        addView(header)
        addView(controlRow)
        
        setPadding(0, 0, 0, (16 * density).toInt())
    }

    private fun vibrate() {
        performHapticFeedback(HapticFeedbackConstants.KEYBOARD_TAP)
    }

    fun setOnMicClickListener(listener: OnClickListener) {
        btnMic.setOnClickListener {
            vibrate()
            listener.onClick(it)
        }
    }

    fun setOnBackClickListener(listener: OnClickListener) {
        btnBack.setOnClickListener {
            vibrate()
            listener.onClick(it)
        }
    }

    fun setOnBackspaceClickListener(listener: OnClickListener) {
        btnBackspace.setOnClickListener {
            vibrate()
            listener.onClick(it)
        }
    }

    fun setOnEnterClickListener(listener: OnClickListener) {
        btnEnter.setOnClickListener {
            vibrate()
            listener.onClick(it)
        }
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
                        Color.parseColor("#B4E197")
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
