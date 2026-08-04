/// App-wide constants: API configuration, source mappings, category list.
///
/// SECURITY NOTE: This key is hardcoded for development/demo purposes only,
/// per the project brief. Anyone who decompiles the built APK/IPA can read
/// this string in plaintext. Before shipping this app publicly, move all
/// NewsAPI calls behind a backend proxy you control, and never embed a
/// production key in a client binary. NewsAPI's free Developer plan also
/// prohibits production/commercial use in its Terms of Service and caps
/// you at 100 requests/day, so this key is not viable for a public release
/// regardless of where it lives.
class ApiConstants {
  static const String apiKey = '';
  static const String baseUrl = 'https://newsapi.org/v2';

  static const String topHeadlines = '$baseUrl/top-headlines';
  static const String everything = '$baseUrl/everything';
}

/// Maps the display name shown in the source picker to the NewsAPI
/// `sources` query parameter value.
class NewsSource {
  final String displayName;
  final String sourceId;

  const NewsSource(this.displayName, this.sourceId);

  static const List<NewsSource> all = [
    NewsSource('All sources', 'all'),
    NewsSource('BBC News', 'bbc-news'),
    NewsSource('CNN', 'cnn'),
    NewsSource('Al Jazeera', 'al-jazeera-english'),
    NewsSource('GEO News', 'geo-news'),
    NewsSource('Dunya News', 'dunya-news'),
  ];

  static const NewsSource defaultSource = NewsSource('All sources', 'all');
}

/// The 7 standard NewsAPI top-headline categories.
class NewsCategory {
  static const List<String> all = [
    'business',
    'entertainment',
    'general',
    'health',
    'science',
    'sports',
    'technology',
  ];

  /// Capitalized label for display in the TabBar.
  static String label(String category) =>
      category[0].toUpperCase() + category.substring(1);
}
