import 'dart:convert';

class PackageModel {
  final int id;
  final String titleAr;
  final String titleEn;
  final double price;
  final int durationDays;
  final List<int> coursesIncluded;

  PackageModel({
    required this.id,
    required this.titleAr,
    required this.titleEn,
    required this.price,
    required this.durationDays,
    required this.coursesIncluded,
  });

  factory PackageModel.fromJson(Map<String, dynamic> json) {
    return PackageModel(
      id: json['id'] ?? 0,
      titleAr: json['title']?['ar'] ?? '',
      titleEn: json['title']?['en'] ?? '',
      price: double.tryParse(json['price'].toString()) ?? 0.0,
      durationDays: int.tryParse(json['duration_days'].toString()) ?? 0,
      coursesIncluded: List<int>.from(json['courses_included'] ?? []),
    );
  }

  String getLocalizedTitle(String locale) {
    return locale == 'ar' ? titleAr : titleEn;
  }
}
