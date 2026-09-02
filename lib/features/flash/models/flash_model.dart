class FlashItem {
  final int id;
  final int courseId;
  final Map<String, dynamic> title;
  final Map<String, dynamic> instructor;
  final Map<String, dynamic> description;
  final String category;
  final List<int> categoryIds;
  final String coverImageUrl;
  final String flashVideoUrl;
  final String flashThumbnail;
  final bool isFree;
  final String wooProductId;
  int likesCount;
  final String duration;

  // Local state
  bool isLiked;
  bool isFavorited;
  bool isSavedForLater;

  FlashItem({
    required this.id,
    required this.courseId,
    required this.title,
    required this.instructor,
    required this.description,
    required this.category,
    this.categoryIds = const [],
    required this.coverImageUrl,
    required this.flashVideoUrl,
    required this.flashThumbnail,
    this.isFree = false,
    this.wooProductId = '',
    this.likesCount = 0,
    this.duration = '0',
    this.isLiked = false,
    this.isFavorited = false,
    this.isSavedForLater = false,
  });

  factory FlashItem.fromJson(Map<String, dynamic> json) {
    return FlashItem(
      id: json['id'] ?? 0,
      courseId: json['course_id'] ?? json['id'] ?? 0,
      title: json['title'] is Map ? Map<String, dynamic>.from(json['title']) : {'en': json['title'] ?? '', 'ar': json['title'] ?? ''},
      instructor: json['instructor'] is Map ? Map<String, dynamic>.from(json['instructor']) : {'en': '', 'ar': ''},
      description: json['description'] is Map ? Map<String, dynamic>.from(json['description']) : {'en': '', 'ar': ''},
      category: json['category'] ?? '',
      categoryIds: json['category_ids'] != null ? List<int>.from(json['category_ids']) : [],
      coverImageUrl: json['cover_image_url'] ?? '',
      flashVideoUrl: json['flash_video_url'] ?? '',
      flashThumbnail: json['flash_thumbnail'] ?? json['cover_image_url'] ?? '',
      isFree: json['is_free'] ?? false,
      wooProductId: json['woo_product_id']?.toString() ?? '',
      likesCount: json['likes_count'] ?? 0,
      duration: json['duration'] ?? '0',
    );
  }

  String getLocalizedTitle(String lang) => _loc(title, lang);
  String getLocalizedInstructor(String lang) => _loc(instructor, lang);
  String getLocalizedDescription(String lang) => _loc(description, lang);

  String _loc(Map<String, dynamic> map, String lang) {
    if (map.containsKey(lang) && map[lang] != null && map[lang].toString().isNotEmpty) {
      return map[lang];
    }
    return map['en'] ?? map['ar'] ?? '';
  }
}
