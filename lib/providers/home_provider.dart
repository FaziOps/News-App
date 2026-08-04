import 'package:flutter/foundation.dart';
import '../models/article.dart';
import '../services/news_api_service.dart';
import '../utils/constants.dart';

enum LoadState { loading, loaded, error }

/// Drives the Home screen: the top 2/3 source-filtered list and the
/// bottom 1/3 global list are independent load states, so a failure or
/// slow load in one never blocks the other.
class HomeProvider extends ChangeNotifier {
  final NewsApiService _api;

  HomeProvider({NewsApiService? api}) : _api = api ?? NewsApiService() {
    _loadMainHeadlines();
    _loadOtherNews();
  }

  NewsSource _selectedSource = NewsSource.defaultSource;
  NewsSource get selectedSource => _selectedSource;

  String _selectedCategory = '';
  String get selectedCategory => _selectedCategory;

  List<Article> _savedArticles = [];
  List<Article> get savedArticles => _savedArticles;

  List<Article> _mainHeadlines = [];
  List<Article> get mainHeadlines => _mainHeadlines;
  LoadState _mainState = LoadState.loading;
  LoadState get mainState => _mainState;
  String _mainError = '';
  String get mainError => _mainError;

  List<Article> _otherNews = [];
  List<Article> get otherNews => _otherNews;
  LoadState _otherState = LoadState.loading;
  LoadState get otherState => _otherState;
  String _otherError = '';
  String get otherError => _otherError;

  bool isSaved(Article article) => _savedArticles.any((a) => a.title == article.title);

  void toggleSave(Article article) {
    if (isSaved(article)) {
      _savedArticles.removeWhere((a) => a.title == article.title);
    } else {
      _savedArticles.add(article);
    }
    notifyListeners();
  }

  Future<void> selectSource(NewsSource source) async {
    _selectedCategory = ''; // Clear category filter when selecting source
    if (source.sourceId == _selectedSource.sourceId) return;
    _selectedSource = source;
    notifyListeners();
    await _loadMainHeadlines();
  }

  Future<void> selectCategory(String category) async {
    if (_selectedCategory == category) {
      _selectedCategory = ''; // Deselect if tapped again
    } else {
      _selectedCategory = category;
    }
    notifyListeners();
    await _loadMainHeadlines();
  }

  Future<void> _loadMainHeadlines() async {
    _mainState = LoadState.loading;
    notifyListeners();
    try {
      final List<Article> articles;
      if (_selectedCategory.isNotEmpty) {
        articles = await _api.fetchTopHeadlinesByCategory(_selectedCategory);
      } else if (_selectedSource.sourceId == 'all') {
        articles = await _api.fetchGlobalTopHeadlines();
      } else {
        articles = await _api.fetchTopHeadlinesBySource(_selectedSource.sourceId);
      }
      _mainHeadlines = articles;
      _mainState = LoadState.loaded;
    } catch (e) {
      _mainError = e.toString();
      _mainState = LoadState.error;
    }
    notifyListeners();
  }

  Future<void> _loadOtherNews() async {
    _otherState = LoadState.loading;
    notifyListeners();
    try {
      final articles = await _api.fetchGlobalTopHeadlines();
      _otherNews = articles;
      _otherState = LoadState.loaded;
    } catch (e) {
      _otherError = e.toString();
      _otherState = LoadState.error;
    }
    notifyListeners();
  }

  Future<void> retryMain() => _loadMainHeadlines();
  Future<void> retryOther() => _loadOtherNews();

  @override
  void dispose() {
    _api.dispose();
    super.dispose();
  }
}
