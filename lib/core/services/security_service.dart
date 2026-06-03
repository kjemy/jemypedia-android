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
  final bool _isScreenRecording = false; // Placeholder for future Android 14 callback

  bool get isSecurityCompromised => 
      _isExternalDisplayConnected || 
      _isScreenRecording || 
      _isRooted || 
      _isEmulator || 
      _isDebuggerConnected;

  bool get isExternalDisplayConnected => _isExternalDisplayConnected;
  bool get isRooted => _isRooted;
  bool get isEmulator => _isEmulator;
  bool get isDebuggerConnected => _isDebuggerConnected;

  Timer? _pollingTimer;

  SecurityService() {
    _startPolling();
  }

  void _startPolling() {
    // Poll every 3 seconds
    _pollingTimer = Timer.periodic(const Duration(seconds: 3), (timer) async {
      await _checkSecurity();
    });
  }

  Future<void> _checkSecurity() async {
    try {
      // 1. External Display Count
      final int externalCount = await _channel.invokeMethod('getExternalDisplaysCount');
      final bool displaysConnected = externalCount > 0;

      // 2. Root/Jailbreak Check
      final bool rooted = await _channel.invokeMethod('isRooted') ?? false;

      // 3. Emulator Check
      final bool emulator = await _channel.invokeMethod('isEmulator') ?? false;

      // 4. Platform Debugger Check
      final bool debuggerPlatform = await _channel.invokeMethod('isDebuggerConnected') ?? false;

      // 5. C++ Native FFI Debugger Check
      final bool debuggerNative = NativeSecurityService.checkDebugger();

      final bool hasDebugger = debuggerPlatform || debuggerNative;

      bool changed = false;
      if (_isExternalDisplayConnected != displaysConnected) {
        _isExternalDisplayConnected = displaysConnected;
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

