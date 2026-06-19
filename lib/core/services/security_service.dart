import 'dart:async';
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

  // Debounce: external display must be detected for 2 consecutive polls before triggering
  int _externalDisplayConfirmCount = 0;
  static const int _requiredConfirmCount = 2; // 2 × 5s = 10 seconds debounce

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
    // Poll every 5 seconds (slightly relaxed to reduce CPU load)
    _pollingTimer = Timer.periodic(const Duration(seconds: 5), (timer) async {
      await _checkSecurity();
    });
  }

  Future<void> _checkSecurity() async {
    try {
      // 1. External Display Count — with debounce to avoid transient virtual displays
      int externalCount = 0;
      try {
        externalCount =
            await _channel.invokeMethod('getExternalDisplaysCount') ?? 0;
      } catch (_) {}

      final bool rawDisplayDetected = externalCount > 0;
      if (rawDisplayDetected) {
        _externalDisplayConfirmCount++;
      } else {
        // Reset counter — display went away, no threat
        _externalDisplayConfirmCount = 0;
      }
      // Only mark as external if detected consistently across multiple polls
      final bool displaysConfirmed =
          _externalDisplayConfirmCount >= _requiredConfirmCount;

      // 2. Root/Jailbreak Check
      final bool rooted = await _channel.invokeMethod('isRooted') ?? false;

      // 3. Emulator Check
      final bool emulator = await _channel.invokeMethod('isEmulator') ?? false;

      // 4. Platform Debugger Check
      final bool debuggerPlatform =
          await _channel.invokeMethod('isDebuggerConnected') ?? false;

      // 5. C++ Native FFI Debugger Check (Windows only — safe on Android too)
      final bool debuggerNative = NativeSecurityService.checkDebugger();

      final bool hasDebugger = debuggerPlatform || debuggerNative;

      // 6. Screen-recording / blacklisted process (OBS, Bandicam, Audacity, etc.)
      //    Uses platform-specific logic: on Windows it checks process names;
      //    on Android it checks MediaProjection / virtual display names.
      bool blacklistedProcess = false;
      try {
        blacklistedProcess =
            await _channel.invokeMethod('isBlacklistedProcessRunning') ?? false;
      } catch (_) {}

      bool screenRecording = false;
      try {
        screenRecording =
            await _channel.invokeMethod('isScreenRecording') ?? false;
      } catch (_) {}

      bool bluetooth = false;
      try {
        bluetooth = await _channel.invokeMethod('isBluetoothEnabled') ?? false;
      } catch (_) {}

      bool wiredHeadset = true;
      try {
        wiredHeadset = await _channel.invokeMethod('isWiredHeadsetOn') ?? true;
      } catch (_) {}

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
