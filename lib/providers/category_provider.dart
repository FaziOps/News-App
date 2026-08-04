import 'package:flutter/foundation.dart';
import '../models/article.dart';
import '../services/news_api_service.dart';
import '../utils/constants.dart';
import 'home_provider.dart';

/// Drives the Category screen's tab bar. Fetches a category's articles
/// lazily the first time its tab is opened, then caches the result so
/// switching tabs back and forth doesn't burn extra API calls — worth
/// caring about on a 100-requests/day free key.
class CategoryProvider extends ChangeNotifier {
  final NewsApiService _api;

  CategoryProvider({NewsApiService? api}) : _api = api ?? NewsApiService();

  final Map<String, List<Article>> _cache = {};
  final Map<String, LoadState> _states = {
    for (final c in NewsCategory.all) c: LoadState.loading,
  };
  final Map<String, String> _errors = {};

  List<Article> articlesFor(String category) => _cache[category] ?? [];
  LoadState stateFor(String category) =>
      _states[category] ?? LoadState.loading;
  String errorFor(String category) => _errors[category] ?? '';

  /// Call when a tab becomes active. No-op if already cached.
  Future<void> ensureLoaded(String category) async {
    if (_cache.containsKey(category)) return;
    await _load(category);
  }

  Future<void> retry(String category) => _load(category, forceReload: true);

  Future<void> _load(String category, {bool forceReload = false}) async {
    if (forceReload) _cache.remove(category);
    _states[category] = LoadState.loading;
    notifyListeners();
    try {
      final articles = await _api.fetchTopHeadlinesByCategory(category);
      _cache[category] = articles;
      _states[category] = LoadState.loaded;
    } catch (e) {
      _errors[category] = e.toString();
      _states[category] = LoadState.error;
    }
    notifyListeners();
  }

  @override
  void dispose() {
    _api.dispose();
    super.dispose();
  }
}
