import 'dart:async';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';

class SecurityService extends ChangeNotifier {
  static const MethodChannel _channel = MethodChannel('jemypedia/security');
  
  bool _isExternalDisplayConnected = false;
  final bool _isScreenRecording = false; // Placeholder for future Android 14 callback

  bool get isSecurityCompromised => _isExternalDisplayConnected || _isScreenRecording;
  bool get isExternalDisplayConnected => _isExternalDisplayConnected;

  Timer? _pollingTimer;

  SecurityService() {
    _startPolling();
  }

  void _startPolling() {
    // Poll every 3 seconds
    _pollingTimer = Timer.periodic(const Duration(seconds: 3), (timer) async {
      await _checkDisplays();
    });
  }

  Future<void> _checkDisplays() async {
    try {
      final int externalCount = await _channel.invokeMethod('getExternalDisplaysCount');
      final bool connected = externalCount > 0;
      
      if (_isExternalDisplayConnected != connected) {
        _isExternalDisplayConnected = connected;
        notifyListeners();
      }
    } on PlatformException catch (e) {
      debugPrint("Failed to get external display count: '${e.message}'.");
    }
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    super.dispose();
  }
}
