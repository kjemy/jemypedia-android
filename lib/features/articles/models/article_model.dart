class ArticleModel {
  final int id;
  final String title;
  final String content;
  final String excerpt;
  final String date;
  final String imageUrl;
  final String author;
  final List<int> categories;

  ArticleModel({
    required this.id,
    required this.title,
    required this.content,
    required this.excerpt,
    required this.date,
    required this.imageUrl,
    this.author = 'Admin',
    this.categories = const [],
  });

  factory ArticleModel.fromJson(Map<String, dynamic> json) {
    String extractText(dynamic field) {
      if (field == null) return '';
      if (field is Map && field.containsKey('rendered')) {
        return field['rendered'].toString();
      }
      return field.toString();
    }

    String img = 'https://jemypedia.com/wp-content/uploads/2026/08/jemypedia_logo.png'; // Better default image
    if (json['_embedded'] != null && json['_embedded']['wp:featuredmedia'] != null) {
      var media = json['_embedded']['wp:featuredmedia'];
      if (media is List && media.isNotEmpty && media[0]['source_url'] != null) {
        img = media[0]['source_url'];
      }
    }

    List<int> cats = [];
    if (json['categories'] != null && json['categories'] is List) {
      cats = List<int>.from(json['categories']);
    }

    return ArticleModel(
      id: json['id'] ?? 0,
      title: extractText(json['title']),
      content: extractText(json['content']),
      excerpt: extractText(json['excerpt']),
      date: json['date'] ?? '',
      imageUrl: img,
      author: 'فريق عمل Jemypedia', // Hardcoded as requested
      categories: cats,
    );
  }

  String getLocalizedTitle(String languageCode) => title;
  String getLocalizedContent(String languageCode) => excerpt; 
  String getLocalizedFullContent(String languageCode) => content;
  String getLocalizedAuthor(String languageCode) => 'فريق عمل Jemypedia';
}

class PostCategoryModel {
  final int id;
  final String name;

  PostCategoryModel({required this.id, required this.name});

  factory PostCategoryModel.fromJson(Map<String, dynamic> json) {
    return PostCategoryModel(
      id: json['id'] ?? 0,
      name: json['name'] ?? '',
    );
  }
}
