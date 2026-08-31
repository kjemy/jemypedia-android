import 'package:flutter/material.dart';
import '../../features/articles/models/article_model.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class ArticlesProvider with ChangeNotifier {
  List<ArticleModel> _articles = [];
  List<PostCategoryModel> _categories = [];
  int _selectedCategoryId = 0; // 0 means all
  bool _isLoading = false;

  List<ArticleModel> get articles => _selectedCategoryId == 0 
      ? _articles 
      : _articles.where((a) => a.categories.contains(_selectedCategoryId)).toList();
      
  List<PostCategoryModel> get categories => _categories;
  int get selectedCategoryId => _selectedCategoryId;
  bool get isLoading => _isLoading;

  Future<void> fetchArticles() async {
    _isLoading = true;
    notifyListeners();

    try {
      // Fetch categories
      final catResponse = await http.get(Uri.parse('https://jemypedia.com/wp-json/wp/v2/categories'));
      if (catResponse.statusCode == 200) {
        final List<dynamic> catData = jsonDecode(catResponse.body);
        _categories = catData.map((j) => PostCategoryModel.fromJson(j)).toList();
      }

      // Fetch posts with embedded media
      final postResponse = await http.get(Uri.parse('https://jemypedia.com/wp-json/wp/v2/posts?_embed'));
      if (postResponse.statusCode == 200) {
        final List<dynamic> postData = jsonDecode(postResponse.body);
        _articles = postData.map((j) => ArticleModel.fromJson(j)).toList();
      }
    } catch (e) {
      debugPrint("Error fetching blog data: $e");
    }

    _isLoading = false;
    notifyListeners();
  }

  void selectCategory(int id) {
    _selectedCategoryId = id;
    notifyListeners();
  }
}
