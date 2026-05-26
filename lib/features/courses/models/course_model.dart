import '../../../core/services/wordpress_service.dart';
import '../../quizzes/models/quiz_model.dart';

class CourseModel {
  final int id;
  final Map<String, dynamic> title; 
  final Map<String, dynamic> brief;
  final Map<String, dynamic> instructor;
  final String duration;
  final String coverImageUrl;
  final bool isNew;
  final bool isFree;
  final String category;
  final Map<String, dynamic> badgeStatus;
  final List<int> categoryIds;
  final String wooProductId;
  final Map<String, dynamic> price;
  final Map<String, dynamic> accessPeriod;
  final String introVideoUrl;
  double progress;
  final List<LessonModel> lessons;
  final List<QuizModel> quizzes; // Embedded quizzes

  CourseModel({
    required this.id,
    required this.title,
    required this.brief,
    required this.instructor,
    required this.duration,
    required this.coverImageUrl,
    this.isNew = false,
    this.isFree = false,
    required this.category,
    required this.badgeStatus,
    this.categoryIds = const [],
    this.wooProductId = '',
    this.price = const {'regular_price': '', 'sale_price': '', 'on_sale': false, 'currency': '\$'},
    this.accessPeriod = const {'ar': '', 'en': ''},
    this.introVideoUrl = '',
    this.progress = 0.0,
    this.lessons = const [],
    this.quizzes = const [],
  });

  factory CourseModel.fromJson(Map<String, dynamic> json) {
    var lessonsList = <LessonModel>[];
    if (json['lessons'] != null) {
      lessonsList = (json['lessons'] as List).map((i) => LessonModel.fromJson(i)).toList();
    }

    var quizzesList = <QuizModel>[];
    if (json['quizzes'] != null) {
      quizzesList = (json['quizzes'] as List).map((i) => QuizModel.fromJson(i)).toList();
    }

    return CourseModel(
      id: json['id'] ?? 0,
      title: json['title'] is Map ? json['title'] : {'en': json['title'] ?? '', 'ar': json['title'] ?? ''},
      brief: json['brief'] is Map ? json['brief'] : {'en': json['brief'] ?? '', 'ar': json['brief'] ?? ''},
      instructor: json['instructor'] is Map ? json['instructor'] : {'en': json['instructor'] ?? 'Dr. Jemy', 'ar': json['instructor'] ?? 'د. جيمي'},
      duration: json['duration'] ?? '0',
      coverImageUrl: WordPressService.normalizeUrl(json['cover_image_url']),
      isNew: json['is_new'] ?? false,
      isFree: json['is_free'] ?? false,
      category: (json['category'] ?? '').toString(),
      badgeStatus: json['badge_status'] != null ? Map<String, dynamic>.from(json['badge_status']) : {'value': 'none', 'ar': '', 'en': '', 'color': '#ff0055'},
      wooProductId: json['woo_product_id']?.toString() ?? '',
      price: json['price'] is Map ? json['price'] : {'regular_price': '', 'sale_price': '', 'on_sale': false, 'currency': '\$'},
      accessPeriod: json['access_period'] is Map ? json['access_period'] : {'ar': '', 'en': ''},
      introVideoUrl: WordPressService.normalizeVideoUrl(json['intro_video_url']),
      categoryIds: json['category_ids'] != null ? List<int>.from(json['category_ids']) : [],
      progress: (json['progress'] ?? 0).toDouble(),
      lessons: lessonsList,
      quizzes: quizzesList,
    );
  }

  String getLocalizedInstructor(String languageCode) => _getLocalized(instructor, languageCode);
  String getLocalizedBrief(String languageCode) => _getLocalized(brief, languageCode);
  String getLocalizedTitle(String languageCode) => _getLocalized(title, languageCode);
  String getLocalizedBadge(String languageCode) => _getLocalized(badgeStatus, languageCode);
  String getLocalizedAccessPeriod(String languageCode) => _getLocalized(accessPeriod, languageCode);

  String _getLocalized(Map<String, dynamic> map, String languageCode) {
    if (map.containsKey(languageCode) && map[languageCode] != null && map[languageCode].toString().isNotEmpty) {
      return map[languageCode];
    }
    return map['en'] ?? map['ar'] ?? '';
  }
}

class LessonModel {
  final int id;
  final Map<String, dynamic> title;
  final String videoUrl;
  final String duration;
  final bool isFreePreview;
  final bool hasMaterials;

  LessonModel({
    required this.id,
    required this.title,
    required this.videoUrl,
    required this.duration,
    this.isFreePreview = false,
    this.hasMaterials = false,
  });

  factory LessonModel.fromJson(Map<String, dynamic> json) {
    return LessonModel(
      id: json['id'] ?? 0,
      title: json['title'] is Map ? json['title'] : {'en': json['title'] ?? '', 'ar': json['title'] ?? ''},
      videoUrl: WordPressService.normalizeUrl(json['video_url']),
      duration: json['duration'] ?? '0',
      isFreePreview: json['is_free_preview'] ?? false,
      hasMaterials: json['has_materials'] ?? false,
    );
  }

  String getLocalizedTitle(String languageCode) {
    if (title.containsKey(languageCode) && title[languageCode] != null && title[languageCode].toString().isNotEmpty) {
      return title[languageCode];
    }
    return title['en'] ?? title['ar'] ?? '';
  }
}
