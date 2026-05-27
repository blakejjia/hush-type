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
        }
    }

    override fun onCreate() {
        super.onCreate()
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
        if (enabled && !isMuted && floatingView == null) {
            setupFloatingWidget()
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
                            isDragging = true
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
                        // Dragging finished. Check if Y is near the bottom to dismiss
                        val displayMetrics = resources.displayMetrics
                        val screenHeight = displayMetrics.heightPixels
                        val dismissThreshold = 120 * displayMetrics.density // 120dp
                        
                        if (layoutParams.y > screenHeight - dismissThreshold) {
                            dismissAndMuteWidget()
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

    private fun dismissAndMuteWidget() {
        floatingView?.animate()
            ?.alpha(0f)
            ?.scaleX(0.5f)
            ?.scaleY(0.5f)
            ?.setDuration(300)
            ?.withEndAction {
                hideFloatingWidget()
                muteWidgetFor15Minutes()
            }
            ?.start()
    }

    private fun muteWidgetFor15Minutes() {
        isMuted = true
        muteHandler.removeCallbacks(unmuteRunnable)
        muteHandler.postDelayed(unmuteRunnable, 15 * 60 * 1000L) // 15 minutes
        
        Toast.makeText(
            this,
            "Floating Mic hidden for 15 minutes. Toggle in settings to show now.",
            Toast.LENGTH_LONG
        ).show()
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
                micIcon?.setImageResource(R.drawable.ic_mic_m3)
                
                // Restore standard colors
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
            is VoiceImeViewModel.ImeState.Recording -> {
                micIcon?.visibility = View.VISIBLE
                spinner?.visibility = View.GONE
                micIcon?.setImageResource(R.drawable.ic_mic_m3)
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
                micIcon?.setImageResource(R.drawable.ic_mic_m3)

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
        val rootNode = rootInActiveWindow
        if (rootNode != null) {
            val focusedNode = rootNode.findFocus(AccessibilityNodeInfo.FOCUS_INPUT)
            if (focusedNode != null && focusedNode.isEditable) {
                // Copy to clipboard first
                val clipboard = getSystemService(Context.CLIPBOARD_SERVICE) as ClipboardManager
                val clip = ClipData.newPlainText("transcription", text)
                clipboard.setPrimaryClip(clip)
                
                // Execute paste
                focusedNode.performAction(AccessibilityNodeInfo.ACTION_PASTE)
                focusedNode.recycle()
                rootNode.recycle()
                return
            }
            rootNode.recycle()
        }

        // Fallback: copy to clipboard only
        val clipboard = getSystemService(Context.CLIPBOARD_SERVICE) as ClipboardManager
        val clip = ClipData.newPlainText("transcription", text)
        clipboard.setPrimaryClip(clip)
        Toast.makeText(this, "Transcribed: $text (Copied)", Toast.LENGTH_SHORT).show()
    }

    override fun onDestroy() {
        super.onDestroy()
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
}
