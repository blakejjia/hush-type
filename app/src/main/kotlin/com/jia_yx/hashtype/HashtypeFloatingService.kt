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

    private val handler = Handler(Looper.getMainLooper())
    private var pulseAnimator: Animator? = null

    // Debounce runnable to avoid flickering during focus transitions
    private val hideRunnable = Runnable {
        if (viewModel.getCurrentState() is VoiceImeViewModel.ImeState.Idle && !isInputActive()) {
            hideFloatingWidget()
        }
    }

    private val preferenceListener = SharedPreferences.OnSharedPreferenceChangeListener { _, key ->
        if (key == "flutter.floating_mic_enabled") {
            handler.post { checkInputFocusState() }
        } else if (key == "flutter.floating_mic_size" ||
                   key == "flutter.floating_mic_color" ||
                   key == "flutter.floating_mic_icon" ||
                   key == "flutter.floating_mic_icon_color") {
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
        checkInputFocusState()
    }

    override fun onAccessibilityEvent(event: AccessibilityEvent?) {
        if (event == null) return
        checkInputFocusState()
    }

    /**
     * Checks if any editable view (e.g. EditText) currently holds input focus.
     */
    private fun isInputActive(): Boolean {
        try {
            // Check active root window first
            val root = rootInActiveWindow
            if (root != null) {
                val focused = root.findFocus(AccessibilityNodeInfo.FOCUS_INPUT)
                if (focused != null) {
                    val editable = focused.isEditable && focused.isFocused
                    focused.recycle()
                    root.recycle()
                    if (editable) return true
                } else {
                    root.recycle()
                }
            }

            // Fallback search across all interactive windows
            val activeWindows = windows
            if (activeWindows != null) {
                for (window in activeWindows) {
                    val wRoot = window.root
                    if (wRoot != null) {
                        val focused = wRoot.findFocus(AccessibilityNodeInfo.FOCUS_INPUT)
                        if (focused != null) {
                            val editable = focused.isEditable && focused.isFocused
                            focused.recycle()
                            wRoot.recycle()
                            if (editable) return true
                        } else {
                            wRoot.recycle()
                        }
                    }
                }
            }
        } catch (e: Exception) {
            Log.d("HashtypeFloatService", "isInputActive error: ${e.message}")
        }
        return false
    }

    private fun checkInputFocusState() {
        val enabled = sharedPreferences.getBoolean("flutter.floating_mic_enabled", true)
        if (!enabled) {
            hideFloatingWidget()
            return
        }

        // Keep visible during Recording or Processing
        val isBusy = viewModel.getCurrentState() !is VoiceImeViewModel.ImeState.Idle
        if (isBusy) {
            handler.removeCallbacks(hideRunnable)
            if (floatingView == null) {
                setupFloatingWidget()
            }
            return
        }

        if (isInputActive()) {
            handler.removeCallbacks(hideRunnable)
            if (floatingView == null) {
                setupFloatingWidget()
            }
        } else {
            // Focus lost: debounce 200ms before hiding
            handler.removeCallbacks(hideRunnable)
            handler.postDelayed(hideRunnable, 200L)
        }
    }

    private fun setupFloatingWidget() {
        if (floatingView != null) return

        val themedContext = DynamicColors.wrapContextIfAvailable(
            this,
            com.google.android.material.R.style.Theme_Material3_DayNight_NoActionBar
        )

        floatingView = LayoutInflater.from(themedContext).inflate(R.layout.layout_floating_mic, null)

        val windowType = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP_MR1) {
            WindowManager.LayoutParams.TYPE_ACCESSIBILITY_OVERLAY
        } else if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY
        } else {
            @Suppress("DEPRECATION")
            WindowManager.LayoutParams.TYPE_PHONE
        }

        params = WindowManager.LayoutParams(
            WindowManager.LayoutParams.WRAP_CONTENT,
            WindowManager.LayoutParams.WRAP_CONTENT,
            windowType,
            WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN,
            PixelFormat.TRANSLUCENT
        ).apply {
            gravity = Gravity.TOP or Gravity.START
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
                    true
                }
                MotionEvent.ACTION_MOVE -> {
                    val deltaX = event.rawX - initialTouchX
                    val deltaY = event.rawY - initialTouchY

                    if (Math.abs(deltaX) > touchSlop || Math.abs(deltaY) > touchSlop) {
                        isDragging = true
                        val displayMetrics = resources.displayMetrics
                        val maxX = displayMetrics.widthPixels - v.width
                        val maxY = displayMetrics.heightPixels - v.height

                        layoutParams.x = (initialX + deltaX).toInt().coerceIn(0, maxX)
                        layoutParams.y = (initialY + deltaY).toInt().coerceIn(0, maxY)
                        windowManager.updateViewLayout(floatingView, layoutParams)
                    }
                    true
                }
                MotionEvent.ACTION_UP -> {
                    if (!isDragging) {
                        vibrate()
                        v.performClick()
                        viewModel.handleMicClick()
                    }
                    true
                }
                else -> false
            }
        }
    }

    private fun hideFloatingWidget() {
        stopPulseAnimation()
        if (floatingView != null) {
            try {
                windowManager.removeView(floatingView)
            } catch (e: Exception) {
                Log.e("HashtypeFloatService", "Error removing floating view: ${e.message}")
            }
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
                        micIcon?.imageTintList = ColorStateList.valueOf(Color.parseColor(iconColorStr))
                    } catch (_: Exception) {
                        val defaultBgColor = MaterialColors.getColor(
                            fabCard,
                            com.google.android.material.R.attr.colorSecondaryContainer,
                            Color.parseColor("#E8DEF8")
                        )
                        fabCard.setCardBackgroundColor(ColorStateList.valueOf(defaultBgColor))
                    }
                }

                // If input is no longer active when returning to Idle, hide with debounce
                checkInputFocusState()
            }
            is VoiceImeViewModel.ImeState.Recording -> {
                micIcon?.visibility = View.VISIBLE
                spinner?.visibility = View.GONE
                micIcon?.setImageResource(getCustomIconResource())
                startPulseAnimation()

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

                val errorBgColor = Color.parseColor("#B3261E")
                fabCard.setCardBackgroundColor(ColorStateList.valueOf(errorBgColor))
                micIcon?.imageTintList = ColorStateList.valueOf(Color.WHITE)

                handler.postDelayed({
                    if (viewModel.getCurrentState() is VoiceImeViewModel.ImeState.Error) {
                        viewModel.reset()
                    }
                }, 2000)
            }
            is VoiceImeViewModel.ImeState.Success -> {
                viewModel.reset()
            }
        }
    }

    override fun onTextCommitted(text: String) {
        insertTextAtCursor(text)
    }

    private fun insertTextAtCursor(text: String) {
        val clipboard = getSystemService(Context.CLIPBOARD_SERVICE) as ClipboardManager
        val clip = ClipData.newPlainText("transcription", text)
        clipboard.setPrimaryClip(clip)

        var pasted = tryPaste()
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
        val rootNode = rootInActiveWindow
        if (rootNode != null) {
            val focusedNode = rootNode.findFocus(AccessibilityNodeInfo.FOCUS_INPUT)
            if (focusedNode != null) {
                pasted = focusedNode.performAction(AccessibilityNodeInfo.ACTION_PASTE)
                focusedNode.recycle()
            }
            rootNode.recycle()
        }

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
                            if (pasted) break
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
    }

    override fun onInterrupt() {}

    override fun onStatusMessageChanged(message: String) {
        Log.d("HashtypeFloatService", "Status: $message")
    }

    override fun onBackspace() {}
    override fun onEnter() {}
    override fun onPeriod() {}
    override fun onOpenSettings() {
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
            else -> Triple(56, 24, 28)
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
                    service.checkInputFocusState()
                    val view = service.floatingView
                    if (view != null) {
                        service.applySizeSettings(view)
                        service.onStateChanged(service.viewModel.getCurrentState())
                    }
                }
            }
        }
    }
}
