import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../providers/home_provider.dart';
import '../providers/category_provider.dart';
import '../widgets/article_card.dart';
import '../widgets/glass_container.dart';
import '../widgets/state_views.dart';
import '../models/article.dart';
import '../utils/constants.dart';
import '../services/news_api_service.dart';
import 'package:cached_network_image/cached_network_image.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;
  
  // Search state
  final TextEditingController _searchController = TextEditingController();
  List<Article> _searchResults = [];
  bool _isSearching = false;
  String _searchError = '';
  final NewsApiService _searchApi = NewsApiService();
  Timer? _debounceTimer;

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _searchController.dispose();
    _searchApi.dispose();
    super.dispose();
  }

  Future<void> _performSearch(String query) async {
    _debounceTimer?.cancel();
    final trimmedQuery = query.trim();
    if (trimmedQuery.isEmpty) {
      setState(() {
        _searchResults.clear();
        _isSearching = false;
        _searchError = '';
      });
      return;
    }

    setState(() {
      _isSearching = true;
      _searchError = '';
    });

    final lowerQuery = trimmedQuery.toLowerCase();
    
    // Stopwords to filter out from keyword matching in multi-word queries
    const stopwords = {
      'a', 'an', 'the', 'and', 'or', 'but', 'is', 'are', 'was', 'were',
      'of', 'in', 'on', 'at', 'to', 'for', 'with', 'by', 'from', 'about', 'as'
    };

    var keywords = lowerQuery
        .split(RegExp(r'\s+'))
        .map((w) => w.replaceAll(RegExp(r'[^\w]'), ''))
        .where((k) => k.isNotEmpty)
        .toList();

    final filteredKeywords = keywords.where((k) => !stopwords.contains(k)).toList();
    if (filteredKeywords.isNotEmpty) {
      keywords = filteredKeywords;
    }

    // 1. Gather all local articles
    final homeProvider = context.read<HomeProvider>();
    final categoryProvider = context.read<CategoryProvider>();

    final allLocal = <Article>[
      ...homeProvider.mainHeadlines,
      ...homeProvider.otherNews,
      ...homeProvider.savedArticles,
      ...NewsCategory.all.expand((c) => categoryProvider.articlesFor(c)),
      ..._dummyMainArticles,
      ..._dummyOtherArticles,
    ];

    // Filter out duplicates based on lowercase title
    final seen = <String>{};
    final uniqueLocal = <Article>[];
    for (final article in allLocal) {
      final key = article.title.trim().toLowerCase();
      if (key.isNotEmpty && !seen.contains(key)) {
        seen.add(key);
        uniqueLocal.add(article);
      }
    }

    // 2. Perform local keyword relevance scoring
    final localMatches = <MapEntry<Article, int>>[];
    for (final article in uniqueLocal) {
      final title = article.title.toLowerCase();
      final desc = (article.description ?? '').toLowerCase();

      int score = 0;
      // High score for exact match of the full search query
      if (title.contains(lowerQuery)) {
        score += 100;
      } else if (desc.contains(lowerQuery)) {
        score += 50;
      }

      // Proportional score for matching individual keywords
      int keywordMatches = 0;
      for (final kw in keywords) {
        if (title.contains(kw)) {
          keywordMatches += 10;
        } else if (desc.contains(kw)) {
          keywordMatches += 5;
        }
      }
      score += keywordMatches;

      if (score > 0) {
        localMatches.add(MapEntry(article, score));
      }
    }

    // Sort matching local articles by relevance score descending
    localMatches.sort((a, b) => b.value.compareTo(a.value));
    final sortedLocal = localMatches.map((e) => e.key).toList();

    // 3. Query the external News API for broader search
    List<Article> apiResults = [];
    String? apiError;
    try {
      apiResults = await _searchApi.searchArticles(trimmedQuery);
    } catch (e) {
      apiError = e.toString();
    }

    // 4. Merge results: prioritize sorted local matches, then add unique API results
    final mergedResults = <Article>[...sortedLocal];
    final mergedTitles = sortedLocal.map((a) => a.title.trim().toLowerCase()).toSet();

    for (final article in apiResults) {
      final titleKey = article.title.trim().toLowerCase();
      if (titleKey.isNotEmpty && !mergedTitles.contains(titleKey)) {
        mergedTitles.add(titleKey);
        mergedResults.add(article);
      }
    }

    setState(() {
      _searchResults = mergedResults;
      _isSearching = false;
      // Show error only if both search types yield nothing and there was an API error
      if (mergedResults.isEmpty && apiError != null) {
        _searchError = apiError;
      }
    });
  }

  String _getFormattedDate() {
    final now = DateTime.now();
    return DateFormat('MMMM d').format(now);
  }

  @override
  Widget build(BuildContext context) {
    final homeProvider = context.watch<HomeProvider>();

    // Determine article lists (use provider data if loaded, otherwise fallback to dummy data)
    final mainList = homeProvider.mainState == LoadState.loaded && homeProvider.mainHeadlines.isNotEmpty
        ? homeProvider.mainHeadlines
        : _dummyMainArticles;
    
    final otherList = homeProvider.otherState == LoadState.loaded && homeProvider.otherNews.isNotEmpty
        ? homeProvider.otherNews
        : _dummyOtherArticles;

    return AppGradientBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        extendBodyBehindAppBar: true,
        extendBody: true,
        appBar: _buildCustomAppBar(),
        body: Stack(
          children: [
            // Page Body Content
            Positioned.fill(
              child: IndexedStack(
                index: _currentIndex,
                children: [
                  // Index 0: Today Feed (2/3 and 1/3 split)
                  _TodayFeed(
                    dateString: _getFormattedDate(),
                    mainArticles: mainList,
                    otherArticles: otherList,
                  ),
                  // Index 1: News+ Tab View (Categories explorer)
                  const _CategoriesPage(),
                  // Index 2: Audio Tab View (Placeholder playlist)
                  const _AudioPage(),
                  // Index 3: Following Tab View (Saved articles)
                  const _SavedPage(),
                  // Index 4: Detached Search Page
                  _buildSearchPage(),
                ],
              ),
            ),

            // Floating Navigation Bar (Today, News+, Audio, Following + Detached Search)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: _buildBottomNavBar(),
            ),
          ],
        ),
      ),
    );
  }

  // --- TOP CUSTOM APP BAR ---
  PreferredSizeWidget _buildCustomAppBar() {
    return PreferredSize(
      preferredSize: const Size.fromHeight(kToolbarHeight),
      child: ClipRRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
          child: AppBar(
            backgroundColor: Colors.white.withOpacity(0.06),
            elevation: 0,
            title: const Text(
              'Daily Glass',
              style: TextStyle(fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: -0.5),
            ),
            centerTitle: true,
            actions: [
              Consumer<HomeProvider>(
                builder: (context, homeProvider, _) {
                  return PopupMenuButton<NewsSource>(
                    icon: const Icon(Icons.more_vert, color: Colors.white),
                    color: const Color(0xFF16193F),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: BorderSide(
                        color: Colors.white.withOpacity(0.12),
                        width: 1,
                      ),
                    ),
                    onSelected: (NewsSource source) {
                      homeProvider.selectSource(source);
                    },
                    itemBuilder: (context) {
                      return NewsSource.all.map((NewsSource source) {
                        final isSelected = source.sourceId == homeProvider.selectedSource.sourceId;
                        return PopupMenuItem<NewsSource>(
                          value: source,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              SizedBox(
                                width: 24,
                                child: isSelected
                                    ? const Icon(
                                        Icons.check,
                                        color: Color(0xFFB08CFF),
                                        size: 18,
                                      )
                                    : null,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                source.displayName,
                                style: TextStyle(
                                  color: isSelected ? const Color(0xFFB08CFF) : Colors.white,
                                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList();
                    },
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  // --- FLOATING BOTTOM NAVIGATION BAR ---
  Widget _buildBottomNavBar() {
    return SafeArea(
      child: GlassContainer(
        borderRadius: 36,
        opacity: 0.16,
        blurSigma: 24,
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
        margin: const EdgeInsets.fromLTRB(20, 0, 20, 16),
        child: Row(
          children: [
            // Standard 4 Nav Items
            Expanded(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildNavItem(0, 'Today', Icons.today),
                  _buildNavItem(1, 'News+', Icons.chrome_reader_mode_outlined),
                  _buildNavItem(2, 'Audio', Icons.headphones_outlined),
                  _buildNavItem(3, 'Following', Icons.folder_copy_outlined),
                ],
              ),
            ),
            // Vertical Separator
            Container(
              height: 32,
              width: 1,
              color: Colors.white24,
              margin: const EdgeInsets.symmetric(horizontal: 12),
            ),
            // Prominent Circular Search Button on the far right
            GestureDetector(
              onTap: () {
                setState(() {
                  _currentIndex = 4;
                });
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: _currentIndex == 4
                      ? const LinearGradient(
                          colors: [Color(0xFF7F00E0), Color(0xFF4A00E0)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        )
                      : null,
                  color: _currentIndex == 4 ? null : Colors.white.withOpacity(0.06),
                  border: Border.all(
                    color: _currentIndex == 4 ? Colors.transparent : Colors.white.withOpacity(0.12),
                    width: 1,
                  ),
                ),
                child: const Icon(
                  Icons.search,
                  color: Colors.white,
                  size: 22,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNavItem(int index, String label, IconData icon) {
    final isSelected = _currentIndex == index;
    final activeColor = Colors.white;
    final inactiveColor = Colors.white.withOpacity(0.4);

    return InkWell(
      onTap: () {
        setState(() {
          _currentIndex = index;
        });
      },
      splashColor: Colors.transparent,
      highlightColor: Colors.transparent,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            color: isSelected ? activeColor : inactiveColor,
            size: 22,
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              color: isSelected ? activeColor : inactiveColor,
              fontSize: 10,
              fontWeight: isSelected ? FontWeight.w800 : FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  // --- SEARCH PAGE ---
  Widget _buildSearchPage() {
    return SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 56), // App Bar spacer
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
            child: Row(
              crossAxisAlignment: Alignment.center == null ? CrossAxisAlignment.center : CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: SizedBox(
                    height: 48,
                    child: GlassContainer(
                      borderRadius: 28,
                      opacity: 0.12,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: TextField(
                        controller: _searchController,
                        style: const TextStyle(color: Colors.white),
                        textAlignVertical: TextAlignVertical.center,
                        decoration: InputDecoration(
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(vertical: 12),
                          icon: const Icon(Icons.search, color: Colors.white70),
                          hintText: 'Search news on any topic...',
                          hintStyle: TextStyle(color: Colors.white.withOpacity(0.5)),
                          border: InputBorder.none,
                          suffixIcon: _searchController.text.isNotEmpty
                              ? IconButton(
                                  padding: EdgeInsets.zero,
                                  icon: const Icon(Icons.clear, color: Colors.white70, size: 18),
                                  onPressed: () {
                                    _debounceTimer?.cancel();
                                    _searchController.clear();
                                    setState(() {
                                      _searchResults.clear();
                                      _isSearching = false;
                                      _searchError = '';
                                    });
                                  },
                                )
                              : null,
                        ),
                        onSubmitted: _performSearch,
                        onChanged: (text) {
                          _debounceTimer?.cancel();
                          final trimmed = text.trim();
                          if (trimmed.isEmpty) {
                            setState(() {
                              _searchResults.clear();
                              _isSearching = false;
                              _searchError = '';
                            });
                          } else {
                            setState(() {});
                            _debounceTimer = Timer(const Duration(milliseconds: 300), () {
                              _performSearch(text);
                            });
                          }
                        },
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                GestureDetector(
                  onTap: () => _performSearch(_searchController.text),
                  child: Container(
                    height: 48,
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF7F00E0), Color(0xFF4A00E0)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(24),
                    ),
                    alignment: Alignment.center,
                    child: const Text(
                      'Search',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: _isSearching
                ? const LoadingView()
                : _searchError.isNotEmpty
                    ? ErrorView(
                        message: _searchError,
                        onRetry: () => _performSearch(_searchController.text),
                      )
                    : _searchController.text.isEmpty
                        ? const Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.search_outlined, size: 64, color: Colors.white30),
                                SizedBox(height: 12),
                                Text(
                                  'Explore Global Headlines',
                                  style: TextStyle(
                                    color: Colors.white70,
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                SizedBox(height: 6),
                                Text(
                                  'Type keywords to find articles from around the world',
                                  style: TextStyle(color: Colors.white38, fontSize: 13),
                                ),
                              ],
                            ),
                          )
                        : _searchResults.isEmpty
                            ? const EmptyView()
                            : ListView.builder(
                                padding: const EdgeInsets.only(top: 8, bottom: 160),
                                itemCount: _searchResults.length,
                                itemBuilder: (context, index) =>
                                    ArticleCard(article: _searchResults[index]),
                              ),
          ),
        ],
      ),
    );
  }
}

// ----------------- CATEGORY EMOJI MAPPING HELPER -----------------
String _getCategoryEmoji(String category) {
  switch (category) {
    case 'business':
      return '💼';
    case 'entertainment':
      return '🎬';
    case 'general':
      return '📰';
    case 'health':
      return '🏥';
    case 'science':
      return '🔬';
    case 'sports':
      return '⚽';
    case 'technology':
      return '💻';
    default:
      return '💡';
  }
}



// ----------------- TODAY FEED WITH PROPORTIONAL SPLIT (2/3 and 1/3) -----------------
class _TodayFeed extends StatelessWidget {
  final String dateString;
  final List<Article> mainArticles;
  final List<Article> otherArticles;

  const _TodayFeed({
    required this.dateString,
    required this.mainArticles,
    required this.otherArticles,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: true,
      bottom: false,
      child: CustomScrollView(
        slivers: [
          // Header content: Date Header Only
          SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 12),
                
                // Dynamic Date Header
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20.0),
                  child: Text(
                    dateString,
                    style: const TextStyle(
                      fontSize: 36,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                      letterSpacing: -1.0,
                    ),
                  ),
                ),
                
                const SizedBox(height: 16),
              ],
            ),
          ),

          // Top Headlines Section Header
          SliverToBoxAdapter(
            child: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 20.0, vertical: 8.0),
              child: Text(
                'Top Headlines',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                ),
              ),
            ),
          ),

          // Top Headlines List
          SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                final article = mainArticles[index];
                if (index == 0) {
                  return FeaturedArticleCard(article: article);
                }
                return ArticleCard(article: article);
              },
              childCount: mainArticles.length,
            ),
          ),



          // Other News Section Header & Separator
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20.0, 24.0, 20.0, 12.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(height: 1, color: Colors.white.withOpacity(0.15)),
                  const SizedBox(height: 16),
                  const Text(
                    'Other News',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Other News List
          SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                final article = otherArticles[index];
                if (index == 0) {
                  return FeaturedArticleCard(article: article);
                }
                return ArticleCard(article: article);
              },
              childCount: otherArticles.length,
            ),
          ),

          // Bottom Spacing to account for the floating bottom navigation bar
          const SliverToBoxAdapter(
            child: SizedBox(height: 120),
          ),
        ],
      ),
    );
  }
}

// ----------------- BACKGROUND GRADIENT WIDGET -----------------
class AppGradientBackground extends StatelessWidget {
  final Widget child;
  const AppGradientBackground({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xFF1E24B4), // Royal Blue / Indigo
            Color(0xFF0F124A), // Deep Navy
            Color(0xFF070821), // Midnight Blue
          ],
          stops: [0.0, 0.5, 1.0],
        ),
      ),
      child: child,
    );
  }
}

// ----------------- AUDIO PAGE PLACEHOLDER -----------------
class _AudioPage extends StatelessWidget {
  const _AudioPage();

  @override
  Widget build(BuildContext context) {
    return const SafeArea(
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.headphones_outlined, size: 64, color: Colors.white30),
            SizedBox(height: 12),
            Text(
              'Audio Headlines',
              style: TextStyle(
                color: Colors.white70,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 6),
            Text(
              'Listen to daily briefing summaries of the top stories',
              style: TextStyle(color: Colors.white38, fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }
}

// ----------------- CATEGORIES EXPLORER -----------------
class _CategoriesPage extends StatefulWidget {
  const _CategoriesPage();

  @override
  State<_CategoriesPage> createState() => _CategoriesPageState();
}

class _CategoriesPageState extends State<_CategoriesPage> {
  String _activeCategory = NewsCategory.all.first;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<CategoryProvider>().ensureLoaded(_activeCategory);
    });
  }

  @override
  Widget build(BuildContext context) {
    final catProvider = context.watch<CategoryProvider>();
    final state = catProvider.stateFor(_activeCategory);
    final articles = catProvider.articlesFor(_activeCategory);

    final displayList = state == LoadState.loaded && articles.isNotEmpty
        ? articles
        : _dummyMainArticles; // Fallback dummy list

    return SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 56), // App Bar spacer
          const Padding(
            padding: EdgeInsets.fromLTRB(20, 20, 20, 10),
            child: Text(
              'Browse Categories',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w900,
                color: Colors.white,
                letterSpacing: -0.5,
              ),
            ),
          ),
          
          // Horizontal Tab/Chip Selector
          Container(
            height: 40,
            margin: const EdgeInsets.only(bottom: 8),
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: NewsCategory.all.length,
              itemBuilder: (context, index) {
                final cat = NewsCategory.all[index];
                final isSelected = cat == _activeCategory;
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4.0),
                  child: GestureDetector(
                    onTap: () {
                      setState(() {
                        _activeCategory = cat;
                      });
                      catProvider.ensureLoaded(cat);
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                      decoration: isSelected
                          ? BoxDecoration(
                              borderRadius: BorderRadius.circular(19),
                              gradient: const LinearGradient(
                                colors: [Color(0xFF7F00E0), Color(0xFF4A00E0)],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFF5100E0).withOpacity(0.3),
                                  blurRadius: 8,
                                  offset: const Offset(0, 3),
                                ),
                              ],
                            )
                          : BoxDecoration(
                              borderRadius: BorderRadius.circular(19),
                              color: Colors.white.withOpacity(0.06),
                              border: Border.all(
                                color: Colors.white.withOpacity(0.12),
                                width: 1,
                              ),
                            ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(_getCategoryEmoji(cat), style: const TextStyle(fontSize: 13)),
                          const SizedBox(width: 6),
                          Text(
                            NewsCategory.label(cat),
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),

          // Categories Feed Body
          Expanded(
            child: state == LoadState.loading
                ? const LoadingView()
                : ListView.builder(
                    padding: const EdgeInsets.only(top: 8, bottom: 160),
                    itemCount: displayList.length,
                    itemBuilder: (context, index) =>
                        ArticleCard(article: displayList[index]),
                  ),
          ),
        ],
      ),
    );
  }
}

// ----------------- SAVED/FOLLOWING ARTICLES PAGE -----------------
class _SavedPage extends StatelessWidget {
  const _SavedPage();

  @override
  Widget build(BuildContext context) {
    final homeProvider = context.watch<HomeProvider>();
    final savedArticles = homeProvider.savedArticles;

    final displayList = savedArticles.isNotEmpty ? savedArticles : _dummyMainArticles;

    return SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 56), // App Bar spacer
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
            child: Text(
              savedArticles.isNotEmpty ? 'Saved Stories' : 'Suggested for You',
              style: const TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w900,
                color: Colors.white,
                letterSpacing: -0.5,
              ),
            ),
          ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.only(top: 8, bottom: 160),
              itemCount: displayList.length,
              itemBuilder: (context, index) =>
                  ArticleCard(article: displayList[index]),
            ),
          ),
        ],
      ),
    );
  }
}

// ----------------- FALLBACK DUMMY DATA -----------------
final List<Article> _dummyMainArticles = [
  Article(
    title: "Here's the biggest news you missed this weekend",
    description: "A summary of major global political shifts, market movements, and breaking updates from the last 48 hours.",
    urlToImage: "https://picsum.photos/id/101/200/200",
    publishedAt: "2026-07-24T12:00:00Z",
    url: "https://news.google.com",
    sourceName: "NBC News",
    author: "Jane Doe",
  ),
  Article(
    title: "A downed airman, a mountain hideout and a secret rescue",
    description: "Inside the high-stakes mission to save a pilot trapped behind enemy lines after a dramatic crash.",
    urlToImage: "https://picsum.photos/id/102/200/200",
    publishedAt: "2026-07-24T11:30:00Z",
    url: "https://news.google.com",
    sourceName: "The Wall Street Journal",
    author: "John Smith",
  ),
  Article(
    title: "Vibrant art exhibitions coming to London museums this season",
    description: "Explore the major visual art collections, retro installations, and indie designs arriving in the city.",
    urlToImage: "https://picsum.photos/id/103/200/200",
    publishedAt: "2026-07-24T10:15:00Z",
    url: "https://news.google.com",
    sourceName: "BBC News",
    author: "Alice Cooper",
  ),
];

final List<Article> _dummyOtherArticles = [
  Article(
    title: "Sports roundup: Match of the day highlights and results",
    description: "A complete recap of the action-packed weekend leagues and player transfers.",
    urlToImage: "https://picsum.photos/id/104/200/200",
    publishedAt: "2026-07-24T09:00:00Z",
    url: "https://news.google.com",
    sourceName: "ESPN",
    author: "Bob Jones",
  ),
  Article(
    title: "Innovations in science: New discoveries in green energy",
    description: "Researchers announce breakthroughs in solar cell efficiencies and battery lifespan extensions.",
    urlToImage: "https://picsum.photos/id/105/200/200",
    publishedAt: "2026-07-24T08:30:00Z",
    url: "https://news.google.com",
    sourceName: "Reuters",
    author: "Charlie Brown",
  ),
];
