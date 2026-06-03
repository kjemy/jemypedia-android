package com.example.jemy_academy_app

import android.content.Context
import android.hardware.display.DisplayManager
import android.os.Build
import android.view.Display
import androidx.annotation.NonNull
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity: FlutterActivity() {
    private val CHANNEL = "jemypedia/security"

    override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            if (call.method == "getExternalDisplaysCount") {
                val displayManager = getSystemService(Context.DISPLAY_SERVICE) as DisplayManager
                val displays = displayManager.displays
                var externalCount = 0
                for (display in displays) {
                    if (display.displayId != Display.DEFAULT_DISPLAY) {
                        externalCount++
                    }
                }
                result.success(externalCount)
            } else {
                result.notImplemented()
            }
        }
    }
}
