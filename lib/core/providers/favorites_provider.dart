import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FavoritesProvider with ChangeNotifier {
  List<String> _favoriteCourseIds = [];
  List<String> _favoriteLessonIds = [];

  List<String> get favoriteCourseIds => _favoriteCourseIds;
  List<String> get favoriteLessonIds => _favoriteLessonIds;

  FavoritesProvider() {
    _loadFavorites();
  }

  Future<void> _loadFavorites() async {
    final prefs = await SharedPreferences.getInstance();
    _favoriteCourseIds = prefs.getStringList('fav_courses') ?? [];
    _favoriteLessonIds = prefs.getStringList('fav_lessons') ?? [];
    notifyListeners();
  }

  bool isCourseFavorite(int id) => _favoriteCourseIds.contains(id.toString());
  bool isLessonFavorite(int id) => _favoriteLessonIds.contains(id.toString());

  Future<void> toggleCourseFavorite(int id) async {
    final idStr = id.toString();
    if (_favoriteCourseIds.contains(idStr)) {
      _favoriteCourseIds.remove(idStr);
    } else {
      _favoriteCourseIds.add(idStr);
    }
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('fav_courses', _favoriteCourseIds);
  }

  Future<void> toggleLessonFavorite(int id) async {
    final idStr = id.toString();
    if (_favoriteLessonIds.contains(idStr)) {
      _favoriteLessonIds.remove(idStr);
    } else {
      _favoriteLessonIds.add(idStr);
    }
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('fav_lessons', _favoriteLessonIds);
  }
}
