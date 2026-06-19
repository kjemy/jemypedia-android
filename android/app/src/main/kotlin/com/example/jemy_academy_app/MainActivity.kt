package com.example.jemy_academy_app

import android.content.Context
import android.hardware.display.DisplayManager
import android.os.Build
import android.view.Display
import androidx.annotation.NonNull
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.EventChannel
import java.io.File
import android.os.Handler
import android.os.Looper

class MainActivity: FlutterActivity() {
    private val CHANNEL = "jemypedia/security"
    private val EVENTS_CHANNEL = "jemypedia/security_events"
    private var eventSink: EventChannel.EventSink? = null


    override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        EventChannel(flutterEngine.dartExecutor.binaryMessenger, EVENTS_CHANNEL).setStreamHandler(
            object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    eventSink = events
                    startDisplayListener()
                }

                override fun onCancel(arguments: Any?) {
                    eventSink = null
                    stopDisplayListener()
                }
            }
        )

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "getExternalDisplaysCount" -> {
                    val displayManager = getSystemService(Context.DISPLAY_SERVICE) as DisplayManager
                    val displays = displayManager.displays
                    var externalCount = 0
                    for (display in displays) {
                        if (display.displayId != Display.DEFAULT_DISPLAY) {
                            val name = display.name.lowercase()
                            val displayStr = display.toString().lowercase()
                            val isVirtual = (name.contains("virtual") || 
                                             name.contains("record") || 
                                             name.contains("capture") ||
                                             name.contains("overlay") ||
                                             name.contains("multiple-display") ||
                                             displayStr.contains("virtual") ||
                                             displayStr.contains("type_virtual") ||
                                             displayStr.contains("type=virtual"))
                            if (!isVirtual) {
                                externalCount++
                            }
                        }
                    }
                    result.success(externalCount)
                }
                "isScreenRecording" -> {
                    result.success(isScreenRecordingActive())
                }
                "isRooted" -> {
                    result.success(isDeviceRooted())
                }
                "isEmulator" -> {
                    result.success(isDeviceEmulator())
                }
                "isDebuggerConnected" -> {
                    result.success(isDebuggerAttached())
                }
                "isBluetoothEnabled" -> {
                    result.success(isBluetoothEnabled())
                }
                "isWiredHeadsetOn" -> {
                    result.success(isWiredHeadsetOn())
                }
                "muteAudio" -> {
                    try {
                        val audioManager = getSystemService(Context.AUDIO_SERVICE) as android.media.AudioManager
                        audioManager.adjustStreamVolume(android.media.AudioManager.STREAM_MUSIC, android.media.AudioManager.ADJUST_MUTE, 0)
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("MUTE_FAILED", e.message, null)
                    }
                }
                "unmuteAudio" -> {
                    try {
                        val audioManager = getSystemService(Context.AUDIO_SERVICE) as android.media.AudioManager
                        audioManager.adjustStreamVolume(android.media.AudioManager.STREAM_MUSIC, android.media.AudioManager.ADJUST_UNMUTE, 0)
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("UNMUTE_FAILED", e.message, null)
                    }
                }
                "stopApp" -> {
                    finishAffinity()
                    result.success(true)
                }
                else -> {
                    result.notImplemented()
                }
            }
        }
    }

    private fun isDeviceRooted(): Boolean {
        val paths = arrayOf(
            "/system/app/Superuser.apk",
            "/sbin/su",
            "/system/bin/su",
            "/system/xbin/su",
            "/data/local/xbin/su",
            "/data/local/bin/su",
            "/system/sd/xbin/su",
            "/system/bin/failsafe/su",
            "/data/local/su"
        )
        for (path in paths) {
            if (File(path).exists()) return true
        }
        val buildTags = Build.TAGS
        if (buildTags != null && buildTags.contains("test-keys")) return true
        return false
    }

    private fun isDeviceEmulator(): Boolean {
        return (Build.BRAND.startsWith("generic") && Build.DEVICE.startsWith("generic"))
                || Build.FINGERPRINT.startsWith("generic")
                || Build.FINGERPRINT.startsWith("unknown")
                || Build.HARDWARE.contains("goldfish")
                || Build.HARDWARE.contains("ranchu")
                || Build.MODEL.contains("google_sdk")
                || Build.MODEL.contains("Emulator")
                || Build.MODEL.contains("Android SDK built for x86")
                || Build.MANUFACTURER.contains("Genymotion")
                || Build.PRODUCT.contains("sdk_google")
                || Build.PRODUCT.contains("google_sdk")
                || Build.PRODUCT.contains("sdk")
                || Build.PRODUCT.contains("sdk_x86")
                || Build.PRODUCT.contains("vbox86p")
                || Build.PRODUCT.contains("emulator")
                || Build.PRODUCT.contains("simulator")
    }

    private fun isDebuggerAttached(): Boolean {
        return android.os.Debug.isDebuggerConnected() || android.os.Debug.waitingForDebugger()
    }

    private fun isBluetoothEnabled(): Boolean {
        try {
            val bluetoothAdapter = android.bluetooth.BluetoothAdapter.getDefaultAdapter()
            return bluetoothAdapter?.isEnabled == true
        } catch (e: Exception) {
            return false
        }
    }

    private fun isWiredHeadsetOn(): Boolean {
        try {
            val audioManager = getSystemService(Context.AUDIO_SERVICE) as android.media.AudioManager
            return audioManager.isWiredHeadsetOn
        } catch (e: Exception) {
            return true 
        }
    }

    private fun isScreenRecordingActive(): Boolean {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.JELLY_BEAN_MR1) {
            val displayManager = getSystemService(Context.DISPLAY_SERVICE) as DisplayManager
            val displays = displayManager.displays
            for (display in displays) {
                if (display.displayId != Display.DEFAULT_DISPLAY) {
                    val name = display.name.lowercase()
                    val displayStr = display.toString().lowercase()
                    if (name.contains("virtual") || 
                        name.contains("record") || 
                        name.contains("capture") ||
                        name.contains("overlay") ||
                        name.contains("multiple-display") ||
                        displayStr.contains("virtual") ||
                        displayStr.contains("type_virtual") ||
                        displayStr.contains("type=virtual")) {
                        return true
                    }
                }
            }
        }
        return false
    }
    private var displayManager: DisplayManager? = null
    private val mainHandler = Handler(Looper.getMainLooper())

    private val displayListener = object : DisplayManager.DisplayListener {
        override fun onDisplayAdded(displayId: Int) { checkDisplayStatus("added", displayId) }
        override fun onDisplayRemoved(displayId: Int) { checkDisplayStatus("removed", displayId) }
        override fun onDisplayChanged(displayId: Int) { checkDisplayStatus("changed", displayId) }
    }

    private fun startDisplayListener() {
        displayManager = getSystemService(Context.DISPLAY_SERVICE) as DisplayManager
        displayManager?.registerDisplayListener(displayListener, mainHandler)
        checkAllDisplays()
    }

    private fun stopDisplayListener() {
        displayManager?.unregisterDisplayListener(displayListener)
    }

    private fun checkAllDisplays() {
        val displays = displayManager?.displays ?: return
        var recordingDetected = false
        for (display in displays) {
            if (display.displayId != Display.DEFAULT_DISPLAY) {
                val name = display.name.lowercase()
                val isVirtual = name.contains("virtual") || name.contains("record") || name.contains("capture") || name.contains("overlay")
                if (isVirtual) recordingDetected = true
            }
        }
        val type = if (recordingDetected) "screen_recording_detected" else "screen_recording_stopped"
        mainHandler.post { eventSink?.success(mapOf("type" to type)) }
    }

    private fun checkDisplayStatus(action: String, displayId: Int) {
        checkAllDisplays()
    }
}
