class MaterialModel {
  final String titleAr;
  final String titleEn;
  final String url;
  final String type; // pdf | video | image | archive | document | file

  MaterialModel({
    required this.titleAr,
    required this.titleEn,
    required this.url,
    required this.type,
  });

  String getLocalizedTitle(String locale) => locale == 'ar' ? titleAr : titleEn;

  factory MaterialModel.fromJson(Map<String, dynamic> json) {
    return MaterialModel(
      titleAr: json['title_ar'] ?? '',
      titleEn: json['title_en'] ?? '',
      url:     json['url'] ?? '',
      type:    json['type'] ?? 'file',
    );
  }
}
