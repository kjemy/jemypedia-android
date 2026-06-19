import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'native_security_service.dart';

class SecurityService extends ChangeNotifier {
  static const MethodChannel _channel = MethodChannel('jemypedia/security');

  bool _isExternalDisplayConnected = false;
  bool _isRooted = false;
  bool _isEmulator = false;
  bool _isDebuggerConnected = false;
  bool _isScreenRecording = false;
  bool _isBluetoothEnabled = false;
  bool _isWiredHeadsetOn = true;
  bool _isBlacklistedProcessRunning = false;

  // Debounce: external display must be detected for 2 consecutive polls (10s) before triggering
  int _externalDisplayConfirmCount = 0;
  static const int _requiredConfirmCount = 2;

  /// The app will CLOSE immediately when a recording app is detected.
  /// Everything else just shows the red warning screen.
  bool get isSecurityCompromised =>
      _isExternalDisplayConnected ||
      _isRooted ||
      _isEmulator ||
      _isDebuggerConnected ||
      _isBlacklistedProcessRunning;

  bool get isExternalDisplayConnected => _isExternalDisplayConnected;
  bool get isRooted => _isRooted;
  bool get isEmulator => _isEmulator;
  bool get isDebuggerConnected => _isDebuggerConnected;
  bool get isScreenRecording => _isScreenRecording;
  bool get isBluetoothEnabled => _isBluetoothEnabled;
  bool get isWiredHeadsetOn => _isWiredHeadsetOn;
  bool get isBlacklistedProcessRunning => _isBlacklistedProcessRunning;

  Timer? _pollingTimer;

  SecurityService() {
    _startPolling();
  }

  void _startPolling() {
    _pollingTimer = Timer.periodic(const Duration(seconds: 5), (timer) async {
      await _checkSecurity();
    });
  }

  /// Kill the app immediately — used when recording software is detected.
  Future<void> _killApp() async {
    try {
      await _channel.invokeMethod('stopApp');
    } catch (_) {}
    // Dart-level force exit as backup
    exit(0);
  }

  Future<void> _checkSecurity() async {
    try {
      // ── 1. External Display (HDMI / Cast / Mirror) ─────────────────────────
      int externalCount = 0;
      try {
        externalCount =
            await _channel.invokeMethod('getExternalDisplaysCount') ?? 0;
      } catch (_) {}

      final bool rawDisplayDetected = externalCount > 0;
      if (rawDisplayDetected) {
        _externalDisplayConfirmCount++;
      } else {
        _externalDisplayConfirmCount = 0;
      }
      final bool displaysConfirmed =
          _externalDisplayConfirmCount >= _requiredConfirmCount;

      // ── 2. Root / Jailbreak ────────────────────────────────────────────────
      final bool rooted = await _channel.invokeMethod('isRooted') ?? false;

      // ── 3. Emulator ────────────────────────────────────────────────────────
      final bool emulator = await _channel.invokeMethod('isEmulator') ?? false;

      // ── 4. Debugger (platform + native FFI) ───────────────────────────────
      final bool debuggerPlatform =
          await _channel.invokeMethod('isDebuggerConnected') ?? false;
      final bool debuggerNative = NativeSecurityService.checkDebugger();
      final bool hasDebugger = debuggerPlatform || debuggerNative;

      // ── 5. Screen / Audio Recording app running? ───────────────────────────
      //    On Windows : scans running process names against a blacklist.
      //    On Android : isBlacklistedProcessRunning always returns false because
      //                 audio capture is blocked at OS level via allowAudioPlaybackCapture=false.
      bool blacklistedProcess = false;
      try {
        blacklistedProcess =
            await _channel.invokeMethod('isBlacklistedProcessRunning') ?? false;
      } catch (_) {}

      // Android only — MediaProjection / virtual display recording detection
      bool screenRecording = false;
      try {
        screenRecording =
            await _channel.invokeMethod('isScreenRecording') ?? false;
      } catch (_) {}

      // ── 6. Bluetooth / Wired (informational only, not used in compromise) ──
      bool bluetooth = false;
      try {
        bluetooth = await _channel.invokeMethod('isBluetoothEnabled') ?? false;
      } catch (_) {}

      bool wiredHeadset = true;
      try {
        wiredHeadset = await _channel.invokeMethod('isWiredHeadsetOn') ?? true;
      } catch (_) {}

      // ── 7. IMMEDIATE KILL: recording app detected ──────────────────────────
      //    We close the app right away — no dialog, no warning, just gone.
      if (blacklistedProcess && !_isBlacklistedProcessRunning) {
        debugPrint(
            '[Security] Recording app detected — closing app immediately.');
        await _killApp();
        return;
      }

      // ── 8. Update state and notify UI ─────────────────────────────────────
      bool changed = false;

      if (_isExternalDisplayConnected != displaysConfirmed) {
        _isExternalDisplayConnected = displaysConfirmed;
        changed = true;
      }
      if (_isScreenRecording != screenRecording) {
        _isScreenRecording = screenRecording;
        changed = true;
      }
      if (_isRooted != rooted) {
        _isRooted = rooted;
        changed = true;
      }
      if (_isEmulator != emulator) {
        _isEmulator = emulator;
        changed = true;
      }
      if (_isDebuggerConnected != hasDebugger) {
        _isDebuggerConnected = hasDebugger;
        changed = true;
      }
      if (_isBluetoothEnabled != bluetooth) {
        _isBluetoothEnabled = bluetooth;
        changed = true;
      }
      if (_isWiredHeadsetOn != wiredHeadset) {
        _isWiredHeadsetOn = wiredHeadset;
        changed = true;
      }
      if (_isBlacklistedProcessRunning != blacklistedProcess) {
        _isBlacklistedProcessRunning = blacklistedProcess;
        changed = true;
      }

      if (changed) {
        notifyListeners();
      }
    } on PlatformException catch (e) {
      debugPrint("Security check failed: '${e.message}'.");
    }
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    super.dispose();
  }
}
