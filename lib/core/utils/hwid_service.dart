import '../services/wordpress_service.dart';

class HwidService {
  /// يحصل على بصمة الجهاز الفريدة (HWID)
  /// يدعم الويب والموبايل (Native)
  static Future<String> getDeviceFingerprint() async {
    return await WordPressService.getDeviceId();
  }
}
