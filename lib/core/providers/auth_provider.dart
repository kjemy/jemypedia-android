import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class AuthProvider with ChangeNotifier {
  final _storage = const FlutterSecureStorage();
  bool _isLoggedIn = false;
  String? _userEmail;
  String? _userPassword;
  String? _displayName;
  String? _omniSecretKey;
  List<dynamic> _subscriptions = [];

  bool get isLoggedIn => _isLoggedIn;
  String? get userEmail => _userEmail;
  String? get userPassword => _userPassword;
  String? get displayName => _displayName;
  String? get omniSecretKey => _omniSecretKey;
  List<dynamic> get subscriptions => _subscriptions;

  Future<void> login(String email, String password, {bool rememberMe = false, Map<String, dynamic>? userData}) async {
    _isLoggedIn = true;
    _userEmail = email;
    _userPassword = password;
    
    if (userData != null) {
      _displayName = userData['display_name'];
      _omniSecretKey = userData['omni_secret_key'];
      _subscriptions = userData['subscriptions'] ?? [];
    }
    
    if (rememberMe) {
      await _storage.write(key: 'email', value: email);
      await _storage.write(key: 'password', value: password);
    } else {
      await _storage.delete(key: 'email');
      await _storage.delete(key: 'password');
    }
    
    notifyListeners();
  }

  void updateUserData(Map<String, dynamic> data) {
    _displayName = data['display_name'];
    _omniSecretKey = data['omni_secret_key'];
    _subscriptions = data['subscriptions'] ?? [];
    notifyListeners();
  }

  Future<Map<String, String>?> getSavedCredentials() async {
    String? email = await _storage.read(key: 'email');
    String? password = await _storage.read(key: 'password');
    if (email != null && password != null) {
      return {'email': email, 'password': password};
    }
    return null;
  }

  Future<void> logout() async {
    _isLoggedIn = false;
    _userEmail = null;
    _userPassword = null;
    // We don't delete saved credentials on logout, just end session
    notifyListeners();
  }
}
