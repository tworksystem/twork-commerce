import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../app_properties.dart';
import '../../../providers/category_provider.dart';
import 'category_card.dart';
import 'recommended_list.dart';

class TabView extends StatefulWidget {
  final TabController tabController;

  const TabView({super.key, required this.tabController});

  @override
  State<TabView> createState() => _TabViewState();
}

class _TabViewState extends State<TabView> {
  bool _requestedCategories = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_requestedCategories) {
      _requestedCategories = true;
      final categoryProvider =
          Provider.of<CategoryProvider>(context, listen: false);
      if (!categoryProvider.hasCategories && !categoryProvider.isLoading) {
        categoryProvider.loadCategories();
      }
    }
  }

  Widget _buildCategorySection(
    BuildContext context,
    CategoryProvider provider,
  ) {
    final categories = provider.categories;

    if (provider.isLoading && categories.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (categories.isEmpty) {
      final message = provider.errorMessage ?? 'No categories available';
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Text(
            message,
            style: Theme.of(context)
                .textTheme
                .bodyMedium
                ?.copyWith(color: Colors.grey[600]),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    return SizedBox(
      height: 120,
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 8.0),
        scrollDirection: Axis.horizontal,
        itemCount: categories.length,
        itemBuilder: (context, index) => CategoryCard(
          category: categories[index],
        ),
      ),
    );
  }

  Widget _buildHomeTab(CategoryProvider provider) {
    return RefreshIndicator(
      color: mediumYellow,
      onRefresh: () => provider.loadCategories(forceRefresh: true),
      child: ListView(
        padding: EdgeInsets.only(
          top: 8,
          bottom: MediaQuery.of(context).padding.bottom + 16,
        ),
        children: [
          _buildCategorySection(context, provider),
          const SizedBox(height: 16.0),
          const RecommendedList(
            shrinkWrap: true,
            physics: NeverScrollableScrollPhysics(),
          ),
        ],
      ),
    );
  }

  Widget _buildGenericTab() {
    return ListView(
      padding: EdgeInsets.only(
        top: 16,
        bottom: MediaQuery.of(context).padding.bottom + 16,
      ),
      children: const [
        RecommendedList(
          shrinkWrap: true,
          physics: NeverScrollableScrollPhysics(),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<CategoryProvider>(
      builder: (context, categoryProvider, _) {
        return TabBarView(
          controller: widget.tabController,
          children: <Widget>[
            _buildHomeTab(categoryProvider),
            _buildGenericTab(),
            _buildGenericTab(),
            _buildGenericTab(),
            _buildGenericTab(),
          ],
        );
      },
    );
  }
}
