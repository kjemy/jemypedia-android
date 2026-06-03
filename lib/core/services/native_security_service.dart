import 'dart:ffi';
import 'dart:io';
import 'package:ffi/ffi.dart';
import 'package:flutter/foundation.dart';

typedef IsDebuggerPresentC = Int32 Function();
typedef IsDebuggerPresentDart = int Function();

typedef VerifyLicenseHashC = Int32 Function(
  Pointer<Utf8> email,
  Pointer<Utf8> hwid,
  Pointer<Utf8> signature,
);
typedef VerifyLicenseHashDart = int Function(
  Pointer<Utf8> email,
  Pointer<Utf8> hwid,
  Pointer<Utf8> signature,
);

class NativeSecurityService {
  static DynamicLibrary? _lib;

  static void init() {
    if (_lib != null) return;
    try {
      if (Platform.isWindows) {
        _lib = DynamicLibrary.open('security_core.dll');
      } else if (Platform.isAndroid) {
        _lib = DynamicLibrary.open('libsecurity_core.so');
      }
    } catch (e) {
      debugPrint('Failed to load native security library: $e');
    }
  }

  /// Checks if a debugger is attached via native API
  static bool checkDebugger() {
    if (kIsWeb) return false;
    init();
    if (_lib == null) return false;
    try {
      final isDebuggerPresent = _lib!
          .lookupFunction<IsDebuggerPresentC, IsDebuggerPresentDart>('is_debugger_present');
      return isDebuggerPresent() == 1;
    } catch (e) {
      debugPrint('Error calling is_debugger_present: $e');
      return false;
    }
  }

  /// Validates the license signature using the native C++ security core
  static bool verifyLicense(String email, String hwid, String signature) {
    if (kIsWeb) return true; // Web doesn't run native FFI
    init();
    if (_lib == null) return false;
    try {
      final verifyLicenseHash = _lib!
          .lookupFunction<VerifyLicenseHashC, VerifyLicenseHashDart>('verify_license_hash');
      
      final emailPtr = email.toNativeUtf8();
      final hwidPtr = hwid.toNativeUtf8();
      final sigPtr = signature.toNativeUtf8();
      
      final result = verifyLicenseHash(emailPtr, hwidPtr, sigPtr);
      
      calloc.free(emailPtr);
      calloc.free(hwidPtr);
      calloc.free(sigPtr);
      
      return result == 1;
    } catch (e) {
      debugPrint('Error calling verify_license_hash: $e');
      return false;
    }
  }
}
