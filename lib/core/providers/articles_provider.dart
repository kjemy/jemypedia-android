import 'package:flutter/material.dart';
import '../../features/articles/models/article_model.dart';
import '../services/wordpress_service.dart';

class ArticlesProvider with ChangeNotifier {
  final WordPressService _apiService = WordPressService();
  
  List<ArticleModel> _articles = [];
  bool _isLoading = false;

  List<ArticleModel> get articles => _articles;
  bool get isLoading => _isLoading;

  Future<void> fetchArticles() async {
    _isLoading = true;
    notifyListeners();

    _articles = await _apiService.getArticles();

    _isLoading = false;
    notifyListeners();
  }
}
