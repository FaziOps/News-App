import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/category_provider.dart';
import '../providers/home_provider.dart';
import '../utils/constants.dart';
import '../widgets/article_card.dart';
import '../widgets/glass_container.dart';
import '../widgets/state_views.dart';

class CategoryScreen extends StatelessWidget {
  const CategoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => CategoryProvider(),
      child: DefaultTabController(
        length: NewsCategory.all.length,
        child: AppBackground(
          child: Scaffold(
            backgroundColor: Colors.transparent,
            appBar: _GlassTabAppBar(),
            body: TabBarView(
              children: NewsCategory.all
                  .map((category) => _CategoryTab(category: category))
                  .toList(),
            ),
          ),
        ),
      ),
    );
  }
}

class _GlassTabAppBar extends StatelessWidget implements PreferredSizeWidget {
  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
        child: AppBar(
          backgroundColor: Colors.white.withOpacity(0.12),
          elevation: 0,
          title: const Text(
            'Categories',
            style: TextStyle(fontWeight: FontWeight.w700, color: Colors.white),
          ),
          bottom: TabBar(
            isScrollable: true,
            indicatorColor: Colors.white,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white60,
            tabs: NewsCategory.all
                .map((c) => Tab(text: NewsCategory.label(c)))
                .toList(),
          ),
        ),
      ),
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight + kTextTabBarHeight);
}

class _CategoryTab extends StatefulWidget {
  final String category;
  const _CategoryTab({required this.category});

  @override
  State<_CategoryTab> createState() => _CategoryTabState();
}

class _CategoryTabState extends State<_CategoryTab>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    // Lazily fetch this tab's articles the first time it's built, so
    // opening the screen doesn't fire all 7 category requests at once.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<CategoryProvider>().ensureLoaded(widget.category);
    });
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Consumer<CategoryProvider>(
      builder: (context, provider, _) {
        final state = provider.stateFor(widget.category);
        switch (state) {
          case LoadState.loading:
            return const LoadingView();
          case LoadState.error:
            return ErrorView(
              message: provider.errorFor(widget.category),
              onRetry: () => provider.retry(widget.category),
            );
          case LoadState.loaded:
            final articles = provider.articlesFor(widget.category);
            if (articles.isEmpty) return const EmptyView();
            return ListView.builder(
              padding: const EdgeInsets.only(top: 8, bottom: 12),
              itemCount: articles.length,
              itemBuilder: (context, index) =>
                  ArticleCard(article: articles[index]),
            );
        }
      },
    );
  }
}
