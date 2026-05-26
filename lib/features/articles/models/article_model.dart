class ArticleModel {
  final int id;
  final Map<String, dynamic> title;
  final Map<String, dynamic> content;
  final String author;
  final String date;
  final String imageUrl;

  ArticleModel({
    required this.id,
    required this.title,
    required this.content,
    required this.author,
    required this.date,
    required this.imageUrl,
  });

  factory ArticleModel.fromJson(Map<String, dynamic> json) {
    return ArticleModel(
      id: json['id'] ?? 0,
      title: json['title'] is Map ? json['title'] : {'en': json['title'] ?? '', 'ar': json['title'] ?? ''},
      content: json['excerpt'] is Map ? json['excerpt'] : {'en': json['excerpt'] ?? '', 'ar': json['excerpt'] ?? ''},
      author: json['author'] ?? 'Admin',
      date: json['date'] ?? '',
      imageUrl: json['cover_image'] ?? 'https://via.placeholder.com/600x400',
    );
  }

  String getLocalizedTitle(String languageCode) {
    return title[languageCode] ?? title['en'] ?? title['ar'] ?? '';
  }

  String getLocalizedContent(String languageCode) {
    return content[languageCode] ?? content['en'] ?? content['ar'] ?? '';
  }
}
