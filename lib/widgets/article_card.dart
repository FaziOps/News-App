import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:provider/provider.dart';
import '../models/article.dart';
import '../providers/home_provider.dart';
import 'glass_container.dart';

/// A single article row: thumbnail, source/date, title, description.
/// Tapping opens the article in the device browser via url_launcher.
class ArticleCard extends StatelessWidget {
  final Article article;

  const ArticleCard({super.key, required this.article});

  String _formatDate(String isoDate) {
    if (isoDate.isEmpty) return '';
    try {
      final date = DateTime.parse(isoDate).toLocal();
      return DateFormat('MMM d, h:mm a').format(date).toUpperCase();
    } catch (_) {
      return '';
    }
  }

  Future<void> _openArticle() async {
    if (article.url.isEmpty) return;
    final uri = Uri.tryParse(article.url);
    if (uri == null) return;
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _openArticle,
      child: GlassContainer(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        padding: const EdgeInsets.all(12),
        borderRadius: 24, // Increased border radius for a modern feel
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: SizedBox(
                width: 88,
                height: 88,
                child: article.urlToImage == null || article.urlToImage!.isEmpty
                    ? _fallbackThumbnail()
                    : CachedNetworkImage(
                        imageUrl: article.urlToImage!,
                        fit: BoxFit.cover,
                        placeholder: (context, url) => Container(
                          color: Colors.white.withOpacity(0.08),
                          child: const Center(
                            child: SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          ),
                        ),
                        errorWidget: (context, url, error) =>
                            _fallbackThumbnail(),
                      ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Upper-cased spaced source and date
                  Text(
                    '${article.sourceName.toUpperCase()} · ${_formatDate(article.publishedAt)}',
                    style: TextStyle(
                      fontSize: 10,
                      color: Colors.white.withOpacity(0.55),
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.5,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  // Title text
                  Text(
                    article.title,
                    style: const TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      height: 1.25,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),
                  // Description and Bookmark row
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Expanded(
                        child: Text(
                          article.description ?? '',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.white.withOpacity(0.45),
                            height: 1.2,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Compact square bookmark button
                      _buildBookmarkButton(context),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBookmarkButton(BuildContext context) {
    return Consumer<HomeProvider>(
      builder: (context, provider, _) {
        final isSaved = provider.isSaved(article);
        return GestureDetector(
          onTap: () => provider.toggleSave(article),
          child: Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: isSaved
                  ? const Color(0xFF603AFB).withOpacity(0.3)
                  : Colors.white.withOpacity(0.06),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: isSaved
                    ? const Color(0xFFB08CFF).withOpacity(0.4)
                    : Colors.white.withOpacity(0.12),
                width: 1,
              ),
            ),
            child: Center(
              child: Icon(
                isSaved ? Icons.bookmark : Icons.bookmark_border,
                color: isSaved ? const Color(0xFFB08CFF) : Colors.white70,
                size: 16,
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _fallbackThumbnail() {
    return Container(
      color: Colors.white.withOpacity(0.08),
      child: const Center(
        child: Icon(Icons.image_not_supported_outlined,
            color: Colors.white30, size: 24),
      ),
    );
  }
}

/// A prominent, large-format card styled specifically for featured stories.
class FeaturedArticleCard extends StatelessWidget {
  final Article article;

  const FeaturedArticleCard({super.key, required this.article});

  String _formatDate(String isoDate) {
    if (isoDate.isEmpty) return '';
    try {
      final date = DateTime.parse(isoDate).toLocal();
      return DateFormat('MMM d, h:mm a').format(date).toUpperCase();
    } catch (_) {
      return '';
    }
  }

  Future<void> _openArticle() async {
    if (article.url.isEmpty) return;
    final uri = Uri.tryParse(article.url);
    if (uri == null) return;
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _openArticle,
      child: GlassContainer(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        padding: EdgeInsets.zero, // Full bleed image
        borderRadius: 24,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Image with rounded top corners and a BREAKING overlay badge
            Stack(
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(24),
                    topRight: Radius.circular(24),
                  ),
                  child: SizedBox(
                    width: double.infinity,
                    height: 180,
                    child: article.urlToImage == null || article.urlToImage!.isEmpty
                        ? Container(
                            color: Colors.white.withOpacity(0.08),
                            child: const Icon(
                              Icons.image_not_supported_outlined,
                              color: Colors.white30,
                              size: 48,
                            ),
                          )
                        : CachedNetworkImage(
                            imageUrl: article.urlToImage!,
                            fit: BoxFit.cover,
                            placeholder: (context, url) => Container(
                              color: Colors.white.withOpacity(0.08),
                              child: const Center(
                                child: CircularProgressIndicator(strokeWidth: 2),
                              ),
                            ),
                            errorWidget: (context, url, error) => Container(
                              color: Colors.white.withOpacity(0.08),
                              child: const Icon(
                                Icons.image_not_supported_outlined,
                                color: Colors.white30,
                                size: 48,
                              ),
                            ),
                          ),
                  ),
                ),
                // "BREAKING" overlay badge at the bottom-left of the image
                Positioned(
                  left: 16,
                  bottom: 16,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        color: const Color(0xFF7F00E0).withOpacity(0.55),
                        child: const Text(
                          'BREAKING',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.0,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            
            // Text Details Area below the image
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Source & Date
                  Text(
                    '${article.sourceName.toUpperCase()} · ${_formatDate(article.publishedAt)}',
                    style: TextStyle(
                      fontSize: 10.5,
                      color: Colors.white.withOpacity(0.55),
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.8,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),
                  // Title
                  Text(
                    article.title,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                      height: 1.2,
                    ),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),
                  // Description & Bookmark row
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Expanded(
                        child: Text(
                          article.description ?? '',
                          style: TextStyle(
                            fontSize: 12.5,
                            color: Colors.white.withOpacity(0.45),
                            height: 1.3,
                          ),
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 12),
                      // Compact glass bookmark button
                      Consumer<HomeProvider>(
                        builder: (context, provider, _) {
                          final isSaved = provider.isSaved(article);
                          return GestureDetector(
                            onTap: () => provider.toggleSave(article),
                            child: Container(
                              width: 38,
                              height: 38,
                              decoration: BoxDecoration(
                                color: isSaved
                                    ? const Color(0xFF603AFB).withOpacity(0.3)
                                    : Colors.white.withOpacity(0.06),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: isSaved
                                      ? const Color(0xFFB08CFF).withOpacity(0.4)
                                      : Colors.white.withOpacity(0.12),
                                  width: 1,
                                ),
                              ),
                              child: Center(
                                child: Icon(
                                  isSaved ? Icons.bookmark : Icons.bookmark_border,
                                  color: isSaved ? const Color(0xFFB08CFF) : Colors.white70,
                                  size: 18,
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
