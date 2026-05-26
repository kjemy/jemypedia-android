import 'package:flutter/material.dart';
import '../../features/courses/models/course_model.dart';
import '../../features/articles/models/article_model.dart';
import '../../features/subscriptions/models/package_model.dart';
import '../models/section_model.dart';
import '../services/wordpress_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class CoursesProvider with ChangeNotifier {
  final WordPressService _apiService = WordPressService();
  
  List<CourseModel> _courses = [];
  List<ArticleModel> _articles = [];
  List<PackageModel> _packages = [];
  List<dynamic> _categories = [];
  List<SectionModel> _sections = [];
  List<int> _watchLaterCourseIds = [];
  List<int> _completedLessonIds = [];
  String _tickerText = 'Welcome to Jemy Academy!';
  double _tickerSpeed = 10.0;
  String _requiredVersion = '2.1.0';
  String _updateUrl = '';
  List<int> _unlockedCourses = [];
  bool _isLoading = false;

  List<CourseModel> get courses => _courses;
  List<ArticleModel> get articles => _articles;
  List<PackageModel> get packages => _packages;
  List<dynamic> get categories => _categories;
  List<SectionModel> get sections => _sections;
  List<int> get watchLaterCourseIds => _watchLaterCourseIds;
  List<int> get completedLessonIds => _completedLessonIds;
  String get tickerText => _tickerText;
  double get tickerSpeed => _tickerSpeed;
  String get requiredVersion => _requiredVersion;
  String get updateUrl => _updateUrl;
  List<int> get unlockedCourses => _unlockedCourses;
  bool get isLoading => _isLoading;

  List<CourseModel> get continueLearningCourses => _courses.where((c) => c.progress > 0 && c.progress < 1.0).toList();
  List<CourseModel> get newCourses => _courses.where((c) => c.isNew).toList();

  void _updateAllProgresses() {
    for (var course in _courses) {
      if (course.lessons.isNotEmpty) {
        int completedCount = course.lessons.where((l) => _completedLessonIds.contains(l.id)).length;
        course.progress = completedCount / course.lessons.length;
      }
    }
    for (var section in _sections) {
      for (var course in section.courses) {
        if (course.lessons.isNotEmpty) {
          int completedCount = course.lessons.where((l) => _completedLessonIds.contains(l.id)).length;
          course.progress = completedCount / course.lessons.length;
        }
      }
    }
  }

  Future<void> fetchCourses() async {
    if (_isLoading) return;
    _isLoading = true;
    notifyListeners();

    try {
      final results = await Future.wait([
        _apiService.getCourses(null),
        _apiService.getArticles(),
        _apiService.getPackages(),
        _apiService.getTicker(),
        _apiService.getCategories(),
        _apiService.getSections(),
      ]);

      _courses = results[0] as List<CourseModel>;
      _articles = results[1] as List<ArticleModel>;
      _packages = results[2] as List<PackageModel>;
      
      final tickerData = results[3] as Map<String, dynamic>;
      _tickerText = tickerData['text'] ?? 'Welcome to Jemy Academy!';
      _tickerSpeed = (tickerData['speed'] ?? 10.0).toDouble();
      _requiredVersion = tickerData['required_version'] ?? '2.1.0';
      _updateUrl = tickerData['update_url'] ?? '';
      
      _categories = results[4] as List<dynamic>;

      final List<dynamic> sectionsData = results[5] as List<dynamic>;
      _sections = sectionsData.map((s) => SectionModel.fromJson(s)).toList();
      _sections.sort((a, b) => a.order.compareTo(b.order));

      final prefs = await SharedPreferences.getInstance();
      
      final cl = prefs.getStringList('completed_lessons') ?? [];
      _completedLessonIds = cl.map((e) => int.tryParse(e) ?? 0).where((id) => id > 0).toList();

      final wl = prefs.getStringList('watch_later') ?? [];
      _watchLaterCourseIds = wl.map((e) => int.tryParse(e) ?? 0).where((id) => id > 0).toList();
      _watchLaterCourseIds = _watchLaterCourseIds.where((id) => _courses.any((c) => c.id == id)).toList();
      await prefs.setStringList('watch_later', _watchLaterCourseIds.map((e) => e.toString()).toList());

      _updateAllProgresses();

    } catch (e) {
      print('Error fetching data: $e');
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<void> markLessonCompleted(int lessonId) async {
    if (!_completedLessonIds.contains(lessonId)) {
      _completedLessonIds.add(lessonId);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList('completed_lessons', _completedLessonIds.map((e) => e.toString()).toList());
      _updateAllProgresses();
      notifyListeners();
    }
  }

  Future<void> toggleWatchLater(int courseId) async {
    final prefs = await SharedPreferences.getInstance();
    if (_watchLaterCourseIds.contains(courseId)) {
      _watchLaterCourseIds.remove(courseId);
    } else {
      _watchLaterCourseIds.add(courseId);
    }
    await prefs.setStringList('watch_later', _watchLaterCourseIds.map((e) => e.toString()).toList());
    notifyListeners();
  }

  Future<Map<String, dynamic>?> verifyUserSubscription(String email, String password, String hwid) async {
    _isLoading = true;
    notifyListeners();

    try {
      final data = await _apiService.checkUserStatus(email, password, hwid);
      if (data != null && data.containsKey('unlocked_courses')) {
        _unlockedCourses = List<int>.from(data['unlocked_courses']);
        _isLoading = false;
        notifyListeners();
        return data;
      }
    } catch (e) {
      print('Error verifying subscription: $e');
    }

    _isLoading = false;
    notifyListeners();
    return null;
  }

  Future<Map<String, dynamic>> getLessonVideoUrl(int lessonId, String email, String password, String hwid) async {
    return await _apiService.getLessonUrl(lessonId, email, password, hwid);
  }

  Map<String, dynamic>? getCategoryDetails(int categoryId) {
    for (var cat in _categories) {
      if (cat['id'] == categoryId) return cat;
      if (cat['children'] != null) {
        for (var child in cat['children']) {
          if (child['id'] == categoryId) return child;
        }
      }
    }
    return null;
  }
}
