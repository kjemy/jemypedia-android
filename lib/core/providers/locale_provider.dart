import 'package:flutter/material.dart';
import 'dart:ui' as ui;

class LocaleProvider with ChangeNotifier {
  late Locale _locale;

  LocaleProvider() {
    // Detect system language
    final systemLocale = ui.PlatformDispatcher.instance.locale;
    if (systemLocale.languageCode == 'en') {
      _locale = const Locale('en');
    } else {
      _locale = const Locale('ar'); // Default to Arabic for all non-English
    }
  }

  Locale get locale => _locale;

  bool get isArabic => _locale.languageCode == 'ar';

  void toggleLocale() {
    if (_locale.languageCode == 'en') {
      _locale = const Locale('ar');
    } else {
      _locale = const Locale('en');
    }
    notifyListeners();
  }
}
