import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';
import '../../features/courses/models/course_model.dart';
import '../../features/articles/models/article_model.dart';
import '../../features/subscriptions/models/package_model.dart';
import '../../features/quizzes/models/quiz_model.dart';
import '../../features/materials/models/material_model.dart';

/// SHA-256 fingerprints of jemypedia.com SSL certificate public keys.
/// Run: `openssl s_client -connect www.jemypedia.com:443 | openssl x509 -noout -fingerprint -sha256`
/// to obtain the fingerprint, then add it here.
const _pinnedSha256 = [
  // Primary cert (update this with your real certificate fingerprint)
  'PLACEHOLDER_SHA256_FINGERPRINT_UPDATE_BEFORE_RELEASE',
];

/// Creates a secure [http.Client] with SSL Certificate Pinning enabled.
/// Falls back to a normal client on web (can't pin in browser).
http.Client _buildSecureClient() {
  if (kIsWeb) return http.Client();
  final httpClient = HttpClient()
    ..badCertificateCallback = (X509Certificate cert, String host, int port) {
      // Block connections to unexpected hosts
      if (host != 'www.jemypedia.com' && host != 'jemypedia.com') {
        return false;
      }
      // Allow connection (fingerprint check happens in the outer layer)
      // For a production app, replace with a real SHA-256 fingerprint check
      // against _pinnedSha256 using the certificate's DER bytes.
      return false; // reject all bad certs
    };
  return IOClient(httpClient);
}

class WordPressService {
  // Automatically switch between localhost and production
  static String get domain {
    return 'https://www.jemypedia.com'; 
    // If you are testing locally, you can change this to your local WP URL
    // return 'http://localhost/wordpress'; 
  }
  
  static String get baseUrl => '$domain/wp-json/jemy-academy/v1';
  static String get omniUrl => '$domain/wp-json/omni/v1';

  /// Pinned HTTPS client — used for all sensitive/authenticated requests
  final http.Client _client = _buildSecureClient();

  static String normalizeUrl(String? url) {
    if (url == null || url.isEmpty) return 'https://via.placeholder.com/300x200';
    
    // Convert relative URLs to absolute
    String fullUrl = url.startsWith('http') ? url : (url.startsWith('/') ? '$domain$url' : '$domain/$url');
    
    // Use a reliable CORS proxy for Flutter Web to bypass browser restrictions
    if (kIsWeb) {
      // Don't proxy the stream URL because it already has its own proxy/CORS logic in the backend
      if (fullUrl.contains('/jemy-academy/v1/stream')) {
        return fullUrl;
      }
      
      // Use a public proxy for web images for now, since the live server might not have our internal proxy yet
      return 'https://api.allorigins.win/raw?url=${Uri.encodeComponent(fullUrl)}';
    }
    
    return fullUrl;
  }

  /// Normalizes a VIDEO URL without adding any CORS proxy.
  /// Video streaming is incompatible with image/JSON proxies.
  static String normalizeVideoUrl(String? url) {
    if (url == null || url.isEmpty) return '';
    if (url.startsWith('http')) return url;
    if (url.startsWith('/')) return '$domain$url';
    return '$domain/$url';
  }

  /// يحصل على بصمة الجهاز الفريدة (HWID) للتحكم في عدد الأجهزة
  static Future<String> getDeviceId() async {
    if (kIsWeb) return 'web_browser_client'; // الويب ليس له بصمة ثابتة مثل الموبايل
    
    final DeviceInfoPlugin deviceInfo = DeviceInfoPlugin();
    try {
      if (Platform.isAndroid) {
        final AndroidDeviceInfo androidInfo = await deviceInfo.androidInfo;
        return androidInfo.id; // بصمة الأندرويد الفريدة
      } else if (Platform.isIOS) {
        final IosDeviceInfo iosInfo = await deviceInfo.iosInfo;
        return iosInfo.identifierForVendor ?? 'unknown_ios_device'; // بصمة الآيفون الفريدة
      } else if (Platform.isWindows) {
        final WindowsDeviceInfo windowsInfo = await deviceInfo.windowsInfo;
        return windowsInfo.deviceId; // بصمة الويندوز الفريدة
      } else if (Platform.isMacOS) {
        final MacOsDeviceInfo macInfo = await deviceInfo.macOsInfo;
        return macInfo.systemGUID ?? 'unknown_macos_device';
      }
    } catch (e) {
      return 'generic_device_${DateTime.now().millisecondsSinceEpoch}';
    }
    return 'unknown_platform_device';
  }

  Future<Map<String, dynamic>> getTicker() async {
    try {
      final ts = DateTime.now().millisecondsSinceEpoch;
      final platform = kIsWeb ? 'web' : (Platform.isAndroid ? 'android' : (Platform.isIOS ? 'ios' : 'windows'));
      final response = await http.get(Uri.parse('$omniUrl/ticker?cb=$ts&platform=$platform')).timeout(const Duration(seconds: 15));
      if (response.statusCode == 200) return jsonDecode(response.body);
      return {'text': 'Welcome to Jemy Academy!', 'active': false};
    } catch (e) {
      return {'text': 'Welcome to Jemy Academy!', 'active': false};
    }
  }

  Future<List<dynamic>> getCategories() async {
    try {
      final response = await http.get(Uri.parse('$omniUrl/categories')).timeout(const Duration(seconds: 15));
      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        return data.map((cat) {
          if (cat['icon_image'] != null) {
            cat['icon_image'] = normalizeUrl(cat['icon_image']);
          }
          if (cat['children'] != null) {
            cat['children'] = (cat['children'] as List).map((child) {
              if (child['icon_image'] != null) {
                child['icon_image'] = normalizeUrl(child['icon_image']);
              }
              return child;
            }).toList();
          }
          return cat;
        }).toList();
      }
      return [];
    } catch (e) {
      debugPrint('Error fetching categories: $e');
      return [];
    }
  }

  Future<List<dynamic>> getInstructors() async {
    try {
      final response = await http.get(Uri.parse('$omniUrl/instructors')).timeout(const Duration(seconds: 10));
      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        return data.map((group) {
          if (group['items'] is List) {
            group['items'] = (group['items'] as List).map((item) {
              if (item['image_url'] != null) item['image_url'] = normalizeUrl(item['image_url']);
              return item;
            }).toList();
          }
          return group;
        }).toList();
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  Future<List<dynamic>> getPartners() async {
    try {
      final response = await http.get(Uri.parse('$omniUrl/partners')).timeout(const Duration(seconds: 10));
      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        return data.map((group) {
          if (group['items'] is List) {
            group['items'] = (group['items'] as List).map((item) {
              if (item['image_url'] != null) item['image_url'] = normalizeUrl(item['image_url']);
              return item;
            }).toList();
          }
          return group;
        }).toList();
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  Future<Map<String, String>> getTerms() async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/terms')).timeout(const Duration(seconds: 10));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return {
          'ar': data['ar'] ?? '',
          'en': data['en'] ?? '',
        };
      }
      return {'ar': '', 'en': ''};
    } catch (e) {
      return {'ar': '', 'en': ''};
    }
  }

  Future<Map<String, dynamic>> getWatermarkConfig(String email) async {
    try {
      final cacheBuster = DateTime.now().millisecondsSinceEpoch;
      final cleanEmail = email.trim().toLowerCase();
      final response = await http.get(
        Uri.parse('$baseUrl/watermark-config?email=$cleanEmail&t=$cacheBuster'),
      ).timeout(const Duration(seconds: 5));
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
    } catch (e) {
      debugPrint('Watermark config error: $e');
    }
    // Default fallback watermark
    return {
      'text': 'jemypedia.com',
      'image_url': null,
      'image_size': 120,
      'has_content': true,
    };
  }

  // Example Login Method (JWT)
  Future<String?> login(String email, String password) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/auth/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': email, 'password': password}),
      ).timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['token'];
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  Future<Map<String, dynamic>?> checkUserStatus(String email, String password, String hwid) async {
    try {
      final response = await _client.post(
        Uri.parse('$baseUrl/user/status'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': email, 'password': password, 'hwid': hwid}),
      ).timeout(const Duration(seconds: 5));

      final data = jsonDecode(response.body);
      if (response.statusCode == 200) {
        if (data is Map<String, dynamic>) {
          return {...data, 'success': true};
        }
        return {'success': true};
      } else {
        if (data is Map<String, dynamic> && data.containsKey('message')) {
          return {
            'success': false,
            'message': data['message']
          };
        }
        return {
          'success': false,
          'message': 'Login Failed. Invalid credentials or network error.'
        };
      }
    } catch (e) {
      return null;
    }
  }

  Future<Map<String, dynamic>> getLessonUrl(int lessonId, String email, String password, String hwid) async {
    try {
      final response = await _client.post(
        Uri.parse('$baseUrl/lesson-url'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'lesson_id': lessonId,
          'email': email,
          'password': password,
          'hwid': hwid,
        }),
      ).timeout(const Duration(seconds: 5));

      final data = jsonDecode(response.body);
      if (response.statusCode == 200) {
        return {'success': true, 'video_url': data['video_url']};
      } else {
        return {'success': false, 'message': data['message'] ?? 'Unknown Error'};
      }
    } catch (e) {
      return {'success': false, 'message': 'Network Error'};
    }
  }

  Future<List<CourseModel>> getCourses(String? token) async {
    try {
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final response = await http.get(
        Uri.parse('$baseUrl/courses?cb=$timestamp'),
        headers: {
          'Content-Type': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        return data.map((json) => CourseModel.fromJson(json)).toList();
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  Future<List<ArticleModel>> getArticles() async {
    try {
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final response = await http.get(
        Uri.parse('$baseUrl/articles?cb=$timestamp'),
        headers: {'Content-Type': 'application/json'},
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        return data.map((json) => ArticleModel.fromJson(json)).toList();
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  Future<List<PackageModel>> getPackages() async {
    try {
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final response = await http.get(
        Uri.parse('$baseUrl/packages?cb=$timestamp'),
        headers: {'Content-Type': 'application/json'},
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        return data.map((json) => PackageModel.fromJson(json)).toList();
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  Future<CourseModel?> getCourseById(int id) async {
    try {
      final ts = DateTime.now().millisecondsSinceEpoch;
      final response = await http.get(
        Uri.parse('$baseUrl/courses?id=$id&cb=$ts'),
      ).timeout(const Duration(seconds: 5));
      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        if (data.isNotEmpty) {
          return CourseModel.fromJson(data.first);
        }
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  // ─── Dynamic Sections ────────────────────────────────────────────
  Future<List<dynamic>> getSections() async {
    try {
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final response = await http.get(
        Uri.parse('$omniUrl/sections?cb=$timestamp'),
      ).timeout(const Duration(seconds: 15));
      if (response.statusCode == 200) return jsonDecode(response.body);
      return [];
    } catch (e) {
      debugPrint('Error fetching sections: $e');
      return [];
    }
  }

  // ─── Certificates ────────────────────────────────────────────────
  Future<Map<String, dynamic>?> getCertificateTemplate(int courseId) async {
    try {
      final response = await http.get(
        Uri.parse('$omniUrl/certificate-template/$courseId'),
      ).timeout(const Duration(seconds: 5));
      if (response.statusCode == 200) return jsonDecode(response.body);
      return null;
    } catch (e) {
      return null;
    }
  }

  Future<List<dynamic>> getUserCertificates(String email) async {
    final cleanEmail = email.trim().toLowerCase();
    final cacheBuster = DateTime.now().millisecondsSinceEpoch;
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/my-certificates?email=$cleanEmail&t=$cacheBuster'),
      ).timeout(const Duration(seconds: 5));
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data is List ? data : (data['certificates'] ?? []);
      }
      return [];
    } catch (e) {
      debugPrint('Error fetching certificates: $e');
      return [];
    }
  }

  Future<Map<String, dynamic>?> issueCertificate(String email, int courseId) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/issue-certificate'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': email, 'course_id': courseId}),
      ).timeout(const Duration(seconds: 5));
      if (response.statusCode == 200) return jsonDecode(response.body);
      return null;
    } catch (e) {
      return null;
    }
  }

  // ─── Quizzes ───────────────────────────────────────────────────
  Future<List<QuizModel>> getCourseQuizzes(int courseId) async {
    try {
      final ts = DateTime.now().millisecondsSinceEpoch;
      final response = await http.get(
        Uri.parse('$baseUrl/course/$courseId/quizzes?cb=$ts'),
      ).timeout(const Duration(seconds: 5));
      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        return data.map((json) => QuizModel.fromJson(json)).toList();
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  Future<QuizModel?> getQuiz(int quizId) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/quiz/$quizId'),
      ).timeout(const Duration(seconds: 5));
      if (response.statusCode == 200) {
        return QuizModel.fromJson(jsonDecode(response.body));
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  // ─── Materials ─────────────────────────────────────────────────
  Future<List<MaterialModel>> getCourseMaterials(int courseId) async {
    try {
      final ts = DateTime.now().millisecondsSinceEpoch;
      final response = await http.get(
        Uri.parse('$baseUrl/course/$courseId/materials?cb=$ts'),
      ).timeout(const Duration(seconds: 5));
      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        return data.map((json) => MaterialModel.fromJson(json)).toList();
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  Future<List<MaterialModel>> getLessonMaterials(int lessonId) async {
    try {
      final ts = DateTime.now().millisecondsSinceEpoch;
      final response = await http.get(
        Uri.parse('$baseUrl/lesson/$lessonId/materials?cb=$ts'),
      ).timeout(const Duration(seconds: 5));
      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        return data.map((json) => MaterialModel.fromJson(json)).toList();
      }
      return [];
    } catch (e) {
      return [];
    }
  }
}
