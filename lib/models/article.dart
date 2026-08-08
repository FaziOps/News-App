/// Represents a single news article returned by NewsAPI.org.
///
/// All fields are nullable-safe on parse: NewsAPI frequently returns nulls
/// for `description`, `urlToImage`, and `author`, so we default those to
/// empty strings / null rather than letting a null propagate and crash a
/// widget that assumes a String.
class Article {
  final String title;
  final String? description;
  final String? urlToImage;
  final String publishedAt;
  final String url;
  final String sourceName;
  final String? author;
  final String? content;

  Article({
    required this.title,
    required this.description,
    required this.urlToImage,
    required this.publishedAt,
    required this.url,
    required this.sourceName,
    required this.author,
    this.content,
  });

  /// Returns cleaned up body content without the NewsAPI `[+123 chars]` suffix,
  /// or falls back to description if content is null or empty.
  String get displayContent {
    final raw = (content != null && content!.trim().isNotEmpty)
        ? content!
        : (description ?? '');
    // Remove pattern like [+1234 chars] from the end of NewsAPI body text
    final cleaned = raw.replaceAll(RegExp(r'\s*\[\+\d+\s+chars\]'), '');
    return cleaned.trim();
  }

  factory Article.fromJson(Map<String, dynamic> json) {
    return Article(
      title: (json['title'] as String?)?.trim().isNotEmpty == true
          ? json['title'] as String
          : 'Untitled article',
      description: json['description'] as String?,
      urlToImage: json['urlToImage'] as String?,
      publishedAt: json['publishedAt'] as String? ?? '',
      url: json['url'] as String? ?? '',
      sourceName: (json['source'] as Map<String, dynamic>?)?['name']
              as String? ??
          'Unknown source',
      author: json['author'] as String?,
      content: json['content'] as String?,
    );
  }
}
