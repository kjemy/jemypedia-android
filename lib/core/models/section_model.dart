import 'package:jemypedia_app/features/courses/models/course_model.dart';

class SectionModel {
  final int id;
  final Map<String, dynamic> title;
  final String cardShape; // rectangle | square | circle
  final double cardWidth;
  final double cardHeight;
  final String scroll; // horizontal | vertical | grid
  final String sortBy;
  final int order;
  final bool showArrows;
  final int seeAllCategory;
  final List<CourseModel> courses;

  SectionModel({
    required this.id,
    required this.title,
    required this.cardShape,
    required this.cardWidth,
    required this.cardHeight,
    required this.scroll,
    required this.sortBy,
    required this.order,
    required this.showArrows,
    required this.seeAllCategory,
    required this.courses,
  });

  factory SectionModel.fromJson(Map<String, dynamic> json) {
    var coursesList = <CourseModel>[];
    if (json['courses'] != null) {
      coursesList = (json['courses'] as List).map((c) => CourseModel.fromJson(c)).toList();
    }
    return SectionModel(
      id: json['id'] ?? 0,
      title: json['title'] is Map ? Map<String, dynamic>.from(json['title']) : {'en': json['title'] ?? '', 'ar': ''},
      cardShape: json['card_shape'] ?? 'rectangle',
      cardWidth: (json['card_width'] ?? 240).toDouble(),
      cardHeight: (json['card_height'] ?? 160).toDouble(),
      scroll: json['scroll'] ?? 'horizontal',
      sortBy: json['sort_by'] ?? 'newest',
      order: json['order'] ?? 0,
      showArrows: json['show_arrows'] ?? false,
      seeAllCategory: json['see_all_category'] ?? 0,
      courses: coursesList,
    );
  }

  String getLocalizedTitle(String lang) {
    if (title.containsKey(lang) && title[lang] != null && title[lang].toString().isNotEmpty) {
      return title[lang];
    }
    return title['en'] ?? title['ar'] ?? '';
  }
}

