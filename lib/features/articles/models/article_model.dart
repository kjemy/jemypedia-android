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

    String img = 'https://via.placeholder.com/600x400';
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

    String authorName = 'Admin';
    if (json['_embedded'] != null && json['_embedded']['author'] != null) {
      var auth = json['_embedded']['author'];
      if (auth is List && auth.isNotEmpty && auth[0]['name'] != null) {
        authorName = auth[0]['name'].toString();
      }
    }

    return ArticleModel(
      id: json['id'] ?? 0,
      title: extractText(json['title']),
      content: extractText(json['content']),
      excerpt: extractText(json['excerpt']),
      date: json['date'] ?? '',
      imageUrl: img,
      author: authorName,
      categories: cats,
    );
  }

  // The website is primarily Arabic, so we can just return the text directly since WP usually handles one language or WPML structure.
  // If it's WPML, the API handles the language per endpoint, but we'll just return the title.
  String getLocalizedTitle(String languageCode) => title;
  String getLocalizedContent(String languageCode) => excerpt; // returning excerpt for list view
  String getLocalizedFullContent(String languageCode) => content;
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
