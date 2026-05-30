package com.jia_yx.hashtype

import android.accessibilityservice.AccessibilityService
import android.animation.Animator
import android.animation.ObjectAnimator
import android.animation.PropertyValuesHolder
import android.animation.ValueAnimator
import android.content.ClipData
import android.content.ClipboardManager
import android.content.Context
import android.content.SharedPreferences
import android.content.res.ColorStateList
import android.graphics.Color
import android.graphics.PixelFormat
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.os.VibrationEffect
import android.os.Vibrator
import android.util.Log
import android.view.Gravity
import android.view.LayoutInflater
import android.view.MotionEvent
import android.view.View
import android.view.ViewConfiguration
import android.view.WindowManager
import android.view.accessibility.AccessibilityEvent
import android.view.accessibility.AccessibilityNodeInfo
import android.view.accessibility.AccessibilityWindowInfo
import android.widget.ImageView
import android.widget.ProgressBar
import android.widget.Toast
import com.google.android.material.card.MaterialCardView
import com.google.android.material.color.DynamicColors
import com.google.android.material.color.MaterialColors

class HashtypeFloatingService : AccessibilityService(), VoiceImeViewModel.Listener {

    private lateinit var windowManager: WindowManager
    private var floatingView: View? = null
    private var params: WindowManager.LayoutParams? = null
    private lateinit var viewModel: VoiceImeViewModel
    private lateinit var sharedPreferences: SharedPreferences

    private var initialX: Int = 0
    private var initialY: Int = 0
    private var initialTouchX: Float = 0f
    private var initialTouchY: Float = 0f
    private var isDragging = false
    private var touchSlop: Float = 0f

    // Long press and drag detection
    private val handler = Handler(Looper.getMainLooper())
    private var isLongPressTriggered = false
    private val longPressRunnable = Runnable {
        isLongPressTriggered = true
        vibrate()
        startVoiceRecording()
    }

    // Dismiss mute timer
    private var isMuted = false
    private val muteHandler = Handler(Looper.getMainLooper())
    private val unmuteRunnable = Runnable {
        isMuted = false
        checkAndShowWidget()
    }

    // Animation helper
    private var pulseAnimator: Animator? = null

    // Dismiss target overlay elements
    private var dismissOverlayView: View? = null
    private var dismissOverlayParams: WindowManager.LayoutParams? = null
    private var hoveredTarget: Int = 0 // 0 = none, 1 = 15m, 2 = 24h

    // Settings listener
    private val preferenceListener = SharedPreferences.OnSharedPreferenceChangeListener { _, key ->
        if (key == "flutter.floating_mic_enabled") {
            val enabled = sharedPreferences.getBoolean("flutter.floating_mic_enabled", false)
            if (enabled) {
                isMuted = false
                muteHandler.removeCallbacks(unmuteRunnable)
                checkAndShowWidget()
            } else {
                hideFloatingWidget()
            }
        } else if (key == "flutter.floating_mic_size" || key == "flutter.floating_mic_color" || key == "flutter.floating_mic_icon" || key == "flutter.floating_mic_icon_color") {
            handler.post {
                val view = floatingView
                if (view != null) {
                    applySizeSettings(view)
                    onStateChanged(viewModel.getCurrentState())
                }
            }
        }
    }

    override fun onCreate() {
        super.onCreate()
        instance = this
        viewModel = VoiceImeViewModel(this)
        viewModel.setListener(this)
        
        windowManager = getSystemService(WINDOW_SERVICE) as WindowManager
        touchSlop = ViewConfiguration.get(this).scaledTouchSlop.toFloat()
        
        sharedPreferences = getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
        sharedPreferences.registerOnSharedPreferenceChangeListener(preferenceListener)
    }

    override fun onServiceConnected() {
        super.onServiceConnected()
        checkAndShowWidget()
    }

    private fun checkAndShowWidget() {
        val enabled = sharedPreferences.getBoolean("flutter.floating_mic_enabled", false)
        val mutedUntil = sharedPreferences.getLong("flutter.floating_mic_muted_until", 0L)
        val currentTime = System.currentTimeMillis()
        val isCurrentlyMuted = currentTime < mutedUntil
        
        if (enabled && !isCurrentlyMuted && floatingView == null) {
            isMuted = false
            setupFloatingWidget()
        } else if (isCurrentlyMuted && floatingView == null) {
            isMuted = true
            val remainingMs = mutedUntil - currentTime
            muteHandler.removeCallbacks(unmuteRunnable)
            if (remainingMs > 0 && remainingMs < 24 * 60 * 60 * 1000L) {
                muteHandler.postDelayed(unmuteRunnable, remainingMs)
            }
        }
    }

    private fun setupFloatingWidget() {
        val themedContext = DynamicColors.wrapContextIfAvailable(
            this,
            com.google.android.material.R.style.Theme_Material3_DayNight_NoActionBar
        )

        floatingView = LayoutInflater.from(themedContext).inflate(R.layout.layout_floating_mic, null)

        params = WindowManager.LayoutParams(
            WindowManager.LayoutParams.WRAP_CONTENT,
            WindowManager.LayoutParams.WRAP_CONTENT,
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O)
                WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY
            else
                @Suppress("DEPRECATION") WindowManager.LayoutParams.TYPE_PHONE,
            WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN,
            PixelFormat.TRANSLUCENT
        ).apply {
            gravity = Gravity.TOP or Gravity.START
            // Position it initially on the center right of screen
            val displayMetrics = resources.displayMetrics
            x = displayMetrics.widthPixels - (80 * displayMetrics.density).toInt()
            y = displayMetrics.heightPixels / 2
        }

        applySizeSettings(floatingView!!)
        windowManager.addView(floatingView, params)
        setupTouchListener()
        viewModel.reset()
    }

    private fun setupTouchListener() {
        val view = floatingView ?: return
        view.setOnTouchListener { v, event ->
            val layoutParams = params ?: return@setOnTouchListener false
            
            when (event.action) {
                MotionEvent.ACTION_DOWN -> {
                    initialX = layoutParams.x
                    initialY = layoutParams.y
                    initialTouchX = event.rawX
                    initialTouchY = event.rawY
                    isDragging = false
                    isLongPressTriggered = false
                    
                    // Only schedule long press if we are in IDLE state (ready to record)
                    if (viewModel.getCurrentState() is VoiceImeViewModel.ImeState.Idle) {
                        handler.postDelayed(longPressRunnable, ViewConfiguration.getLongPressTimeout().toLong())
                    }
                    true
                }
                MotionEvent.ACTION_MOVE -> {
                    val deltaX = event.rawX - initialTouchX
                    val deltaY = event.rawY - initialTouchY
                    
                    if (Math.abs(deltaX) > touchSlop || Math.abs(deltaY) > touchSlop) {
                        // Cancel long press timer because user is moving/dragging
                        handler.removeCallbacks(longPressRunnable)
                        
                        if (!isLongPressTriggered) {
                            if (!isDragging) {
                                isDragging = true
                                showDismissOverlay()
                            }
                            layoutParams.x = (initialX + deltaX).toInt()
                            layoutParams.y = (initialY + deltaY).toInt()
                            
                            // Bounds safety (prevent completely dragging off screen)
                            val displayMetrics = resources.displayMetrics
                            val maxX = displayMetrics.widthPixels - v.width
                            val maxY = displayMetrics.heightPixels - v.height
                            if (layoutParams.x < 0) layoutParams.x = 0
                            if (layoutParams.x > maxX) layoutParams.x = maxX
                            if (layoutParams.y < 0) layoutParams.y = 0
                            if (layoutParams.y > maxY) layoutParams.y = maxY

                            windowManager.updateViewLayout(floatingView, layoutParams)
                            updateHoverTargets(event.rawX, event.rawY)
                        }
                    }
                    true
                }
                MotionEvent.ACTION_UP, MotionEvent.ACTION_CANCEL -> {
                    handler.removeCallbacks(longPressRunnable)
                    
                    if (isLongPressTriggered) {
                        // Push-to-talk ends: release stops recording and transcribes
                        vibrate()
                        stopVoiceRecording()
                    } else if (isDragging) {
                        // Dragging finished. Check overlay target
                        val target = hoveredTarget
                        hideDismissOverlay()
                        
                        if (target == 1) {
                            dismissAndMuteWidget(15 * 60 * 1000L)
                        } else if (target == 2) {
                            dismissAndMuteWidget(24 * 60 * 60 * 1000L)
                        }
                    } else {
                        // Short press (Click) logic
                        vibrate()
                        v.performClick()
                        handleMicClicked()
                    }
                    true
                }
                else -> false
            }
        }
    }

    private fun handleMicClicked() {
        viewModel.handleMicClick()
    }

    private fun startVoiceRecording() {
        if (viewModel.getCurrentState() is VoiceImeViewModel.ImeState.Idle) {
            viewModel.startRecording()
        }
    }

    private fun stopVoiceRecording() {
        if (viewModel.getCurrentState() is VoiceImeViewModel.ImeState.Recording) {
            viewModel.stopRecordingAndTranscribe()
        }
    }

    private fun dismissAndMuteWidget(durationMs: Long) {
        floatingView?.animate()
            ?.alpha(0f)
            ?.scaleX(0.5f)
            ?.scaleY(0.5f)
            ?.setDuration(300)
            ?.withEndAction {
                hideFloatingWidget()
                muteWidgetForDuration(durationMs)
            }
            ?.start()
    }

    private fun muteWidgetForDuration(durationMs: Long) {
        isMuted = true
        val muteUntil = System.currentTimeMillis() + durationMs
        sharedPreferences.edit().putLong("flutter.floating_mic_muted_until", muteUntil).apply()
        
        muteHandler.removeCallbacks(unmuteRunnable)
        muteHandler.postDelayed(unmuteRunnable, durationMs)
    }

    private fun showDismissOverlay() {
        if (dismissOverlayView != null) return
        
        val themedContext = DynamicColors.wrapContextIfAvailable(
            this,
            com.google.android.material.R.style.Theme_Material3_DayNight_NoActionBar
        )
        
        dismissOverlayView = LayoutInflater.from(themedContext).inflate(R.layout.layout_dismiss_targets, null)
        
        val density = resources.displayMetrics.density
        val overlayHeightPx = (170 * density).toInt()
        
        dismissOverlayParams = WindowManager.LayoutParams(
            WindowManager.LayoutParams.MATCH_PARENT,
            overlayHeightPx,
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O)
                WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY
            else
                @Suppress("DEPRECATION") WindowManager.LayoutParams.TYPE_PHONE,
            WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN,
            PixelFormat.TRANSLUCENT
        ).apply {
            gravity = Gravity.BOTTOM or Gravity.CENTER_HORIZONTAL
            x = 0
            y = 0
        }
        
        val bottomPanel = dismissOverlayView?.findViewById<View>(R.id.bottom_panel)
        bottomPanel?.translationY = overlayHeightPx.toFloat()
        bottomPanel?.alpha = 0f
        
        try {
            windowManager.addView(dismissOverlayView, dismissOverlayParams)
            hoveredTarget = 0
            
            bottomPanel?.animate()
                ?.translationY(0f)
                ?.alpha(1f)
                ?.setDuration(250)
                ?.start()
        } catch (e: Exception) {
            Log.e("HashtypeFloatService", "Error showing dismiss overlay: ${e.message}")
        }
    }

    private fun hideDismissOverlay() {
        val view = dismissOverlayView ?: return
        val bottomPanel = view.findViewById<View>(R.id.bottom_panel)
        val density = resources.displayMetrics.density
        val overlayHeightPx = if (view.height > 0) view.height.toFloat() else (170 * density)
        
        dismissOverlayView = null
        dismissOverlayParams = null
        hoveredTarget = 0
        
        bottomPanel?.animate()
            ?.translationY(overlayHeightPx)
            ?.alpha(0f)
            ?.setDuration(200)
            ?.withEndAction {
                try {
                    windowManager.removeView(view)
                } catch (e: Exception) {
                    Log.e("HashtypeFloatService", "Error removing dismiss overlay: ${e.message}")
                }
            }
            ?.start()
    }

    private fun updateHoverTargets(rawX: Float, rawY: Float) {
        val overlayView = dismissOverlayView ?: return
        val displayMetrics = resources.displayMetrics
        val screenHeight = displayMetrics.heightPixels
        val screenWidth = displayMetrics.widthPixels
        
        val density = displayMetrics.density
        val overlayHeightPx = (170 * density).toInt()
        
        val inDismissZone = rawY > (screenHeight - overlayHeightPx)
        
        val card15m = overlayView.findViewById<MaterialCardView>(R.id.card_mute_15m) ?: return
        val card24h = overlayView.findViewById<MaterialCardView>(R.id.card_mute_24h) ?: return
        
        var currentTarget = 0
        if (inDismissZone) {
            currentTarget = if (rawX < screenWidth / 2f) 1 else 2
        }
        
        if (currentTarget != hoveredTarget) {
            hoveredTarget = currentTarget
            vibrate()
            
            animateCardHover(card15m, hoveredTarget == 1, false)
            animateCardHover(card24h, hoveredTarget == 2, true)
        }
    }

    private fun animateCardHover(card: MaterialCardView, isHovered: Boolean, isDayCard: Boolean) {
        val scale = if (isHovered) 1.12f else 1.0f
        
        card.animate()
            .scaleX(scale)
            .scaleY(scale)
            .setDuration(150)
            .start()
            
        if (isHovered) {
            if (isDayCard) {
                card.strokeColor = Color.parseColor("#FFB4AB")
                card.setCardBackgroundColor(ColorStateList.valueOf(Color.parseColor("#4DB3261E")))
            } else {
                card.strokeColor = Color.parseColor("#D0BCFF")
                card.setCardBackgroundColor(ColorStateList.valueOf(Color.parseColor("#4D6750A4")))
            }
        } else {
            card.strokeColor = Color.parseColor("#33FFFFFF")
            card.setCardBackgroundColor(ColorStateList.valueOf(Color.parseColor("#26FFFFFF")))
        }
    }

    private fun hideFloatingWidget() {
        stopPulseAnimation()
        if (floatingView != null) {
            windowManager.removeView(floatingView)
            floatingView = null
        }
    }

    private fun startPulseAnimation() {
        val fabCard = floatingView?.findViewById<View>(R.id.fab_card) ?: return
        pulseAnimator = ObjectAnimator.ofPropertyValuesHolder(
            fabCard,
            PropertyValuesHolder.ofFloat("scaleX", 1.0f, 1.15f),
            PropertyValuesHolder.ofFloat("scaleY", 1.0f, 1.15f)
        ).apply {
            duration = 600
            repeatCount = ValueAnimator.INFINITE
            repeatMode = ValueAnimator.REVERSE
            start()
        }
    }

    private fun stopPulseAnimation() {
        pulseAnimator?.cancel()
        pulseAnimator = null
        val fabCard = floatingView?.findViewById<View>(R.id.fab_card)
        fabCard?.scaleX = 1.0f
        fabCard?.scaleY = 1.0f
    }

    private fun vibrate() {
        val vibrator = getSystemService(Context.VIBRATOR_SERVICE) as? Vibrator ?: return
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            vibrator.vibrate(VibrationEffect.createOneShot(50, VibrationEffect.DEFAULT_AMPLITUDE))
        } else {
            @Suppress("DEPRECATION")
            vibrator.vibrate(50)
        }
    }

    // VoiceImeViewModel.Listener implementations

    override fun onStateChanged(state: VoiceImeViewModel.ImeState) {
        val view = floatingView ?: return
        val micIcon = view.findViewById<ImageView>(R.id.mic_icon)
        val spinner = view.findViewById<ProgressBar>(R.id.loading_spinner)
        val fabCard = view.findViewById<MaterialCardView>(R.id.fab_card) ?: return

        when (state) {
            is VoiceImeViewModel.ImeState.Idle -> {
                stopPulseAnimation()
                micIcon?.visibility = View.VISIBLE
                spinner?.visibility = View.GONE
                micIcon?.setImageResource(getCustomIconResource())
                
                // Restore standard or custom colors
                val colorStr = sharedPreferences.getString("flutter.floating_mic_color", "theme") ?: "theme"
                if (colorStr == "theme") {
                    val defaultBgColor = MaterialColors.getColor(
                        fabCard,
                        com.google.android.material.R.attr.colorSecondaryContainer,
                        Color.parseColor("#E8DEF8")
                    )
                    val defaultIconColor = MaterialColors.getColor(
                        fabCard,
                        com.google.android.material.R.attr.colorOnSecondaryContainer,
                        Color.parseColor("#21005D")
                    )
                    fabCard.setCardBackgroundColor(ColorStateList.valueOf(defaultBgColor))
                    micIcon?.imageTintList = ColorStateList.valueOf(defaultIconColor)
                } else {
                    try {
                        val bgColor = Color.parseColor(colorStr)
                        fabCard.setCardBackgroundColor(ColorStateList.valueOf(bgColor))
                        
                        val iconColorStr = sharedPreferences.getString("flutter.floating_mic_icon_color", "#FFFFFF") ?: "#FFFFFF"
                        val iconColor = Color.parseColor(iconColorStr)
                        micIcon?.imageTintList = ColorStateList.valueOf(iconColor)
                    } catch (e: Exception) {
                        val defaultBgColor = MaterialColors.getColor(
                            fabCard,
                            com.google.android.material.R.attr.colorSecondaryContainer,
                            Color.parseColor("#E8DEF8")
                        )
                        val defaultIconColor = MaterialColors.getColor(
                            fabCard,
                            com.google.android.material.R.attr.colorOnSecondaryContainer,
                            Color.parseColor("#21005D")
                        )
                        fabCard.setCardBackgroundColor(ColorStateList.valueOf(defaultBgColor))
                        micIcon?.imageTintList = ColorStateList.valueOf(defaultIconColor)
                    }
                }
            }
            is VoiceImeViewModel.ImeState.Recording -> {
                micIcon?.visibility = View.VISIBLE
                spinner?.visibility = View.GONE
                micIcon?.setImageResource(getCustomIconResource())
                startPulseAnimation()

                // Highlight recording color (Error container is a nice crimson tint in dynamic theme)
                val recordingBgColor = MaterialColors.getColor(
                    fabCard,
                    com.google.android.material.R.attr.colorErrorContainer,
                    Color.parseColor("#F9DEDC")
                )
                val recordingIconColor = MaterialColors.getColor(
                    fabCard,
                    com.google.android.material.R.attr.colorOnErrorContainer,
                    Color.parseColor("#410E0B")
                )
                fabCard.setCardBackgroundColor(ColorStateList.valueOf(recordingBgColor))
                micIcon?.imageTintList = ColorStateList.valueOf(recordingIconColor)
            }
            is VoiceImeViewModel.ImeState.Processing -> {
                stopPulseAnimation()
                micIcon?.visibility = View.GONE
                spinner?.visibility = View.VISIBLE

                // Optional: set spinner color to primary
                val primaryColor = MaterialColors.getColor(
                    fabCard,
                    com.google.android.material.R.attr.colorPrimary,
                    Color.parseColor("#6750A4")
                )
                spinner?.indeterminateTintList = ColorStateList.valueOf(primaryColor)
            }
            is VoiceImeViewModel.ImeState.Error -> {
                stopPulseAnimation()
                micIcon?.visibility = View.VISIBLE
                spinner?.visibility = View.GONE
                micIcon?.setImageResource(getCustomIconResource())

                // Error visual: background turns bright red
                val errorBgColor = Color.parseColor("#B3261E") // MD3 standard error
                val errorIconColor = Color.WHITE
                fabCard.setCardBackgroundColor(ColorStateList.valueOf(errorBgColor))
                micIcon?.imageTintList = ColorStateList.valueOf(errorIconColor)

                // Short post-delay to reset back to idle visually
                handler.postDelayed({
                    if (viewModel.getCurrentState() is VoiceImeViewModel.ImeState.Error) {
                        viewModel.reset()
                    }
                }, 2000)
            }
            is VoiceImeViewModel.ImeState.Success -> {
                // Return to idle
                viewModel.reset()
            }
        }
    }

    override fun onTextCommitted(text: String) {
        insertTextAtCursor(text)
    }

    private fun insertTextAtCursor(text: String) {
        // Copy to clipboard first
        val clipboard = getSystemService(Context.CLIPBOARD_SERVICE) as ClipboardManager
        val clip = ClipData.newPlainText("transcription", text)
        clipboard.setPrimaryClip(clip)

        // Try pasting immediately
        var pasted = tryPaste()

        // If it failed, try again after a small delay (allowing clipboard and focus to settle)
        if (!pasted) {
            handler.postDelayed({
                val retryPasted = tryPaste()
                if (!retryPasted) {
                    Toast.makeText(this, "Transcribed: $text (Copied)", Toast.LENGTH_SHORT).show()
                }
            }, 100)
        }
    }

    private fun tryPaste(): Boolean {
        var pasted = false

        // 1. Try rootInActiveWindow first
        val rootNode = rootInActiveWindow
        if (rootNode != null) {
            val focusedNode = rootNode.findFocus(AccessibilityNodeInfo.FOCUS_INPUT)
            if (focusedNode != null) {
                pasted = focusedNode.performAction(AccessibilityNodeInfo.ACTION_PASTE)
                focusedNode.recycle()
            }
            rootNode.recycle()
        }

        // 2. If not pasted, search through all windows
        if (!pasted) {
            val activeWindows = windows
            if (activeWindows != null) {
                for (window in activeWindows) {
                    val root = window.root
                    if (root != null) {
                        val focusedNode = root.findFocus(AccessibilityNodeInfo.FOCUS_INPUT)
                        if (focusedNode != null) {
                            pasted = focusedNode.performAction(AccessibilityNodeInfo.ACTION_PASTE)
                            focusedNode.recycle()
                            root.recycle()
                            if (pasted) {
                                break
                            }
                        } else {
                            root.recycle()
                        }
                    }
                }
            }
        }

        return pasted
    }

    override fun onDestroy() {
        super.onDestroy()
        instance = null
        sharedPreferences.unregisterOnSharedPreferenceChangeListener(preferenceListener)
        hideFloatingWidget()
        handler.removeCallbacksAndMessages(null)
        muteHandler.removeCallbacksAndMessages(null)
    }

    override fun onAccessibilityEvent(event: AccessibilityEvent?) {
        // We only listen for focused inputs via findFocus when insertion is requested.
        // No constant logging needed here.
    }

    override fun onInterrupt() {}

    override fun onStatusMessageChanged(message: String) {
        Log.d("HashtypeFloatService", "Status: $message")
    }

    override fun onBackspace() {}
    override fun onEnter() {}
    override fun onPeriod() {}
    override fun onOpenSettings() {
        // Allow opening Settings
        val intent = android.content.Intent(this, MainActivity::class.java).apply {
            addFlags(android.content.Intent.FLAG_ACTIVITY_NEW_TASK)
        }
        startActivity(intent)
    }

    private fun getCustomIconResource(): Int {
        val iconStr = sharedPreferences.getString("flutter.floating_mic_icon", "mic") ?: "mic"
        return when (iconStr) {
            "heart" -> R.drawable.ic_heart_m3
            "star" -> R.drawable.ic_star_m3
            "chat" -> R.drawable.ic_chat_m3
            "music" -> R.drawable.ic_music_m3
            else -> R.drawable.ic_mic_m3
        }
    }

    private fun applySizeSettings(view: View) {
        val fabCard = view.findViewById<MaterialCardView>(R.id.fab_card) ?: return
        val micIcon = view.findViewById<ImageView>(R.id.mic_icon) ?: return
        val spinner = view.findViewById<ProgressBar>(R.id.loading_spinner) ?: return

        val sizeStr = sharedPreferences.getString("flutter.floating_mic_size", "medium") ?: "medium"
        val density = resources.displayMetrics.density

        val (cardSizeDp, iconSizeDp, spinnerSizeDp) = when (sizeStr) {
            "small" -> Triple(44, 20, 22)
            "large" -> Triple(68, 28, 34)
            else -> Triple(56, 24, 28) // medium
        }

        val cardSizePx = (cardSizeDp * density).toInt()
        val iconSizePx = (iconSizeDp * density).toInt()
        val spinnerSizePx = (spinnerSizeDp * density).toInt()

        val cardParams = fabCard.layoutParams
        cardParams.width = cardSizePx
        cardParams.height = cardSizePx
        fabCard.layoutParams = cardParams
        fabCard.radius = (cardSizeDp / 2f) * density

        val iconParams = micIcon.layoutParams
        iconParams.width = iconSizePx
        iconParams.height = iconSizePx
        micIcon.layoutParams = iconParams

        val spinnerParams = spinner.layoutParams
        spinnerParams.width = spinnerSizePx
        spinnerParams.height = spinnerSizePx
        spinner.layoutParams = spinnerParams

        val layoutParams = params
        if (layoutParams != null && floatingView != null && floatingView?.windowToken != null) {
            windowManager.updateViewLayout(floatingView, layoutParams)
        }
    }

    companion object {
        @Volatile
        private var instance: HashtypeFloatingService? = null

        fun updateSettings() {
            instance?.let { service ->
                service.handler.post {
                    val enabled = service.sharedPreferences.getBoolean("flutter.floating_mic_enabled", false)
                    if (enabled) {
                        if (service.floatingView == null) {
                            service.isMuted = false
                            service.muteHandler.removeCallbacks(service.unmuteRunnable)
                            service.setupFloatingWidget()
                        } else {
                            service.applySizeSettings(service.floatingView!!)
                            service.onStateChanged(service.viewModel.getCurrentState())
                        }
                    } else {
                        service.hideFloatingWidget()
                    }
                }
            }
        }
    }
}
