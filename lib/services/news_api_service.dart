import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/article.dart';
import '../utils/constants.dart';

/// Thrown when NewsAPI returns a non-'ok' status, or the request fails.
class NewsApiException implements Exception {
  final String message;
  NewsApiException(this.message);

  @override
  String toString() => message;
}

/// Wraps every NewsAPI.org call the app needs. Each method returns a
/// `List<Article>` on success and throws a [NewsApiException] on failure,
/// so callers only need one try/catch path.
class NewsApiService {
  final http.Client _client;

  NewsApiService({http.Client? client}) : _client = client ?? http.Client();

  Future<List<Article>> fetchTopHeadlinesBySource(String sourceId) async {
    final Uri uri;
    if (sourceId == 'geo-news') {
      uri = Uri.parse(
        '${ApiConstants.everything}?q=Geo%20News&language=en&apiKey=${ApiConstants.apiKey}',
      );
    } else if (sourceId == 'dunya-news') {
      uri = Uri.parse(
        '${ApiConstants.everything}?q=Dunya%20News&language=en&apiKey=${ApiConstants.apiKey}',
      );
    } else {
      uri = Uri.parse(
        '${ApiConstants.topHeadlines}?sources=$sourceId&apiKey=${ApiConstants.apiKey}',
      );
    }
    return _fetchArticles(uri);
  }

  Future<List<Article>> fetchGlobalTopHeadlines() async {
    final uri = Uri.parse(
      '${ApiConstants.topHeadlines}?language=en&apiKey=${ApiConstants.apiKey}',
    );
    return _fetchArticles(uri);
  }

  Future<List<Article>> fetchTopHeadlinesByCategory(String category) async {
    final uri = Uri.parse(
      '${ApiConstants.topHeadlines}?category=$category&language=en&apiKey=${ApiConstants.apiKey}',
    );
    return _fetchArticles(uri);
  }

  Future<List<Article>> searchArticles(String query) async {
    final uri = Uri.parse(
      '${ApiConstants.everything}?q=${Uri.encodeComponent(query)}&language=en&apiKey=${ApiConstants.apiKey}',
    );
    return _fetchArticles(uri);
  }

  Future<List<Article>> _fetchArticles(Uri uri) async {
    http.Response response;
    try {
      response = await _client.get(uri).timeout(const Duration(seconds: 15));
    } catch (e) {
      throw NewsApiException('Network error. Check your connection.');
    }

    Map<String, dynamic> body;
    try {
      body = jsonDecode(response.body) as Map<String, dynamic>;
    } catch (e) {
      throw NewsApiException('Failed to load news.');
    }

    if (response.statusCode != 200 || body['status'] != 'ok') {
      final message = body['message'] as String? ?? 'Failed to load news.';
      throw NewsApiException(message);
    }

    final articlesJson = body['articles'] as List<dynamic>? ?? [];
    return articlesJson
        .map((a) => Article.fromJson(a as Map<String, dynamic>))
        .toList();
  }

  void dispose() => _client.close();
}
