import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/flash_model.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';

class FlashProvider extends ChangeNotifier {
  static const String _flashApiBase = 'https://www.jemypedia.com/wp-json/jemy-flash/v1';

  List<FlashItem> _items = [];
  bool _isLoading = false;
  String? _error;
  int _currentPage = 1;
  int _totalPages = 1;

  // Local favorites & saved sets (course IDs)
  Set<int> _favoritedCourseIds = {};
  Set<int> _savedCourseIds = {};
  Set<int> _likedFlashIds = {};

  List<FlashItem> get items => _items;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get hasMore => _currentPage < _totalPages;

  FlashProvider() {
    _loadLocalState();
  }

  // ─── Load local like/fav/save state ────────────────────
  Future<void> _loadLocalState() async {
    final prefs = await SharedPreferences.getInstance();
    _likedFlashIds = (prefs.getStringList('flash_liked') ?? []).map(int.parse).toSet();
    _favoritedCourseIds = (prefs.getStringList('flash_favorited') ?? []).map(int.parse).toSet();
    _savedCourseIds = (prefs.getStringList('flash_saved') ?? []).map(int.parse).toSet();

    // Apply to existing items
    for (var item in _items) {
      item.isLiked = _likedFlashIds.contains(item.courseId);
      item.isFavorited = _favoritedCourseIds.contains(item.courseId);
      item.isSavedForLater = _savedCourseIds.contains(item.courseId);
    }
    notifyListeners();
  }

  Future<void> _saveLocalState() async {
    final prefs = await SharedPreferences.getInstance();
    prefs.setStringList('flash_liked', _likedFlashIds.map((e) => e.toString()).toList());
    prefs.setStringList('flash_favorited', _favoritedCourseIds.map((e) => e.toString()).toList());
    prefs.setStringList('flash_saved', _savedCourseIds.map((e) => e.toString()).toList());
  }

  // ─── Fetch Flash items ─────────────────────────────────
  Future<void> fetchFlashItems({bool refresh = false}) async {
    if (_isLoading) return;

    if (refresh) {
      _currentPage = 1;
      _items.clear();
    }

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final response = await http.get(
        Uri.parse('$_flashApiBase/items?page=$_currentPage&per_page=20'),
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final List<dynamic> flashList = data['flash_items'] ?? [];
        _totalPages = data['total_pages'] ?? 1;

        final newItems = flashList.map((j) => FlashItem.fromJson(j)).toList();

        // Apply local state
        for (var item in newItems) {
          item.isLiked = _likedFlashIds.contains(item.courseId);
          item.isFavorited = _favoritedCourseIds.contains(item.courseId);
          item.isSavedForLater = _savedCourseIds.contains(item.courseId);
        }


        _items.addAll(newItems);
        _currentPage++;
        
        // Background pre-resolve YouTube URLs
        _preResolveUrls(newItems);

      } else {
        _error = 'Failed to load Flash items (${response.statusCode})';
      }
    } catch (e) {
      _error = 'Network error: $e';
    }

    _isLoading = false;
    notifyListeners();
  }

  // ─── Like ──────────────────────────────────────────────
  Future<void> toggleLike(FlashItem item) async {
    item.isLiked = !item.isLiked;
    if (item.isLiked) {
      item.likesCount++;
      _likedFlashIds.add(item.courseId);
    } else {
      item.likesCount--;
      _likedFlashIds.remove(item.courseId);
    }
    notifyListeners();
    _saveLocalState();

    // Fire-and-forget to server
    if (item.isLiked) {
      try {
        await http.post(
          Uri.parse('$_flashApiBase/like'),
          headers: {'Content-Type': 'application/json'},
          body: json.encode({'course_id': item.courseId}),
        );
      } catch (_) {}
    }
  }

  // ─── Favorite (add course to favorites) ────────────────
  void toggleFavorite(FlashItem item) {
    item.isFavorited = !item.isFavorited;
    if (item.isFavorited) {
      _favoritedCourseIds.add(item.courseId);
    } else {
      _favoritedCourseIds.remove(item.courseId);
    }
    notifyListeners();
    _saveLocalState();
  }

  Future<void> _preResolveUrls(List<FlashItem> newItems) async {
    final yt = YoutubeExplode();
    for (var item in newItems) {
      if (item.flashVideoUrl.contains('youtube.com') || item.flashVideoUrl.contains('youtu.be')) {
        try {
          final video = await yt.videos.get(item.flashVideoUrl);
          final manifest = await yt.videos.streamsClient.getManifest(video.id);
          final muxedStreams = manifest.muxed.sortByVideoQuality().toList();
          final streamInfo = muxedStreams.firstWhere(
            (s) => s.videoQuality.name.contains('360') || s.videoQuality.name.contains('480'),
            orElse: () => muxedStreams.last,
          );
          item.resolvedUrl = streamInfo.url.toString();
        } catch (e) {
          debugPrint('Pre-resolve error: $e');
        }
      } else {
        item.resolvedUrl = item.flashVideoUrl;
      }
    }
    yt.close();
  }

  // ─── Save for Later (add course to watch later) ───────
  void toggleSaveForLater(FlashItem item) {
    item.isSavedForLater = !item.isSavedForLater;
    if (item.isSavedForLater) {
      _savedCourseIds.add(item.courseId);
    } else {
      _savedCourseIds.remove(item.courseId);
    }
    notifyListeners();
    _saveLocalState();
  }

  bool isFavorited(int courseId) => _favoritedCourseIds.contains(courseId);
  bool isSaved(int courseId) => _savedCourseIds.contains(courseId);
}
