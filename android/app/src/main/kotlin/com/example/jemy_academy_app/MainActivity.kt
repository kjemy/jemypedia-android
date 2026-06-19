package com.example.jemy_academy_app

import android.app.Activity
import android.content.Context
import android.hardware.display.DisplayManager
import android.media.AudioManager
import android.media.projection.MediaProjectionManager
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.view.Display
import android.view.WindowManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    companion object {
        private const val SECURITY_CHANNEL = "com.jemy.academy/security"
        private const val SECURITY_EVENTS = "com.jemy.academy/security_events"
        private const val DISPLAY_CHANNEL = "com.jemy.academy/display"
    }

    private var securityEventSink: EventChannel.EventSink? = null
    private val handler = Handler(Looper.getMainLooper())
    private var monitoringRunnable: Runnable? = null
    private var wasRecordingDetected = false

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // ─── 1) تفعيل FLAG_SECURE على النافذة (يمنع التقاط الشاشة) ───
        window.addFlags(WindowManager.LayoutParams.FLAG_SECURE)

        // ─── 2) MethodChannel لطلبات مباشرة من Flutter ───
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, SECURITY_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "isScreenRecording" -> result.success(isScreenBeingCaptured())
                    "stopApp" -> {
                        finishAffinity()
                        result.success(true)
                    }
                    "muteAudio" -> {
                        muteSystemAudio(true)
                        result.success(true)
                    }
                    "unmuteAudio" -> {
                        muteSystemAudio(false)
                        result.success(true)
                    }
                    else -> result.notImplemented()
                }
            }

        // ─── 3) DisplayChannel للتحقق من الشاشات الافتراضية ───
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, DISPLAY_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "hasVirtualDisplay" -> result.success(hasVirtualDisplay())
                    else -> result.notImplemented()
                }
            }

        // ─── 4) EventChannel يبث أحداث تسجيل الشاشة تلقائياً ───
        EventChannel(flutterEngine.dartExecutor.binaryMessenger, SECURITY_EVENTS)
            .setStreamHandler(object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    securityEventSink = events
                    startSecurityMonitor()
                }
                override fun onCancel(arguments: Any?) {
                    securityEventSink = null
                    stopSecurityMonitor()
                }
            })
    }

    // ─── فحص إذا كانت الشاشة يتم التقاطها ───────────────────────────────────
    private fun isScreenBeingCaptured(): Boolean {
        // فحص 1: شاشات افتراضية (Virtual Displays)
        if (hasVirtualDisplay()) return true

        // فحص 2: على Android 11+ نفحص AudioPlaybackCaptureConfiguration
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            try {
                val audioManager = getSystemService(Context.AUDIO_SERVICE) as AudioManager
                // إذا كان النظام يسجل الصوت من التطبيقات
                val isCapturing = audioManager.isMusicActive.not() == false
                // هذا للرصد فقط - الاعتماد الرئيسي على hasVirtualDisplay
            } catch (e: Exception) {
                // تجاهل
            }
        }

        // فحص 3: Scrcpy يستخدم Virtual Display
        return false
    }

    // ─── فحص الشاشات الافتراضية ──────────────────────────────────────────────
    private fun hasVirtualDisplay(): Boolean {
        val displayManager = getSystemService(Context.DISPLAY_SERVICE) as DisplayManager
        val displays = displayManager.displays
        for (display in displays) {
            val name = display.name.lowercase()
            val displayStr = display.toString().lowercase()
            // Virtual displays من برامج التسجيل
            if (name.contains("virtual") ||
                name.contains("capture") ||
                name.contains("mirror") ||
                name.contains("cast") ||
                name.contains("overlay") ||
                name.contains("scrcpy") ||
                name.contains("adb") ||
                name.contains("screenrecorder") ||
                displayStr.contains("type virtual") ||
                displayStr.contains("displaytype virtual") ||
                display.displayId != Display.DEFAULT_DISPLAY) {

                // تحقق إضافي: هل هذا Display يحاكي شاشتنا؟
                if (display.displayId != Display.DEFAULT_DISPLAY) {
                    // أي display إضافي مشبوه
                    return true
                }
            }
        }
        return false
    }

    // ─── كتم / رفع صوت النظام ────────────────────────────────────────────────
    private fun muteSystemAudio(mute: Boolean) {
        val audioManager = getSystemService(Context.AUDIO_SERVICE) as AudioManager
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            audioManager.adjustStreamVolume(
                AudioManager.STREAM_MUSIC,
                if (mute) AudioManager.ADJUST_MUTE else AudioManager.ADJUST_UNMUTE,
                0
            )
        } else {
            audioManager.setStreamMute(AudioManager.STREAM_MUSIC, mute)
        }
    }

    // ─── مراقب الأمان التلقائي ────────────────────────────────────────────────
    private fun startSecurityMonitor() {
        monitoringRunnable = object : Runnable {
            override fun run() {
                val isCapturing = isScreenBeingCaptured()

                if (isCapturing && !wasRecordingDetected) {
                    wasRecordingDetected = true
                    // كتم الصوت فوراً
                    muteSystemAudio(true)
                    // إبلاغ Flutter
                    securityEventSink?.success(mapOf(
                        "type" to "screen_recording_detected",
                        "action" to "stop_and_mute"
                    ))
                } else if (!isCapturing && wasRecordingDetected) {
                    wasRecordingDetected = false
                    // إعادة الصوت
                    muteSystemAudio(false)
                    // إبلاغ Flutter
                    securityEventSink?.success(mapOf(
                        "type" to "screen_recording_stopped",
                        "action" to "resume"
                    ))
                }

                handler.postDelayed(this, 500) // فحص كل 500ms
            }
        }
        handler.post(monitoringRunnable!!)
    }

    private fun stopSecurityMonitor() {
        monitoringRunnable?.let { handler.removeCallbacks(it) }
        monitoringRunnable = null
        // إعادة الصوت عند إيقاف المراقب
        muteSystemAudio(false)
    }

    override fun onDestroy() {
        stopSecurityMonitor()
        muteSystemAudio(false)
        super.onDestroy()
    }
}
