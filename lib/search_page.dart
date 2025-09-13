import 'dart:async';
import 'package:flutter/material.dart';

import 'model.dart';
import 'services/firebase_service.dart';
import 'product_card.dart';
import 'product_detail_page.dart';

/// SearchPage
/// Shows:
///  - AppBar with a search field
///  - Tabs: All + each Category
///  - In ALL states (normal tabs or searching) we use ProductCard in minimal layout
///    (image + name only) as you requested.
///  - When user taps a product, navigates to ProductDetailPage (full info shown there).
///
/// Assumptions:
///  - FirebaseService exposes: watchCategories(), watchTopProductsByCategory(), watchProductsByCategory(), watchSearchProducts()
///  - ProductCard already updated with enum ProductCardLayout { full, minimal }
class SearchPage extends StatefulWidget {
  final String currentWarehouseId;
  const SearchPage({super.key, required this.currentWarehouseId});

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> with SingleTickerProviderStateMixin {
  final _svc = FirebaseService();
  final _searchCtrl = TextEditingController();
  Timer? _debounce;

  bool _isSearching = false;
  bool _showFilterBar = false; // (kept for future use, currently cosmetic only)
  TabController? _tabController;

  static const int lowStockThreshold = 50; // kept for potential future conditional styling

  @override
  void initState() {
    super.initState();
    _searchCtrl.addListener(_onSearchChanged);
  }

  void _onSearchChanged() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      if (!mounted) return;
      setState(() {
        _isSearching = _searchCtrl.text.trim().isNotEmpty;
      });
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchCtrl.dispose();
    _tabController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const themeRed = Color(0xFFE53935);

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(themeRed),
            Expanded(
              child: _isSearching
                  ? _buildSearchResults()
                  : _buildCategoryTabs(),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------- Header (AppBar area) ----------------
  Widget _buildHeader(Color themeRed) {
    return Container(
      color: themeRed,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 8, 8, 12),
            child: Row(
              children: [
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.arrow_back, color: Colors.white),
                  splashRadius: 24,
                ),
                const SizedBox(width: 4),
                Expanded(child: _buildSearchField()),
                const SizedBox(width: 4),
                IconButton(
                  onPressed: () => setState(() => _showFilterBar = !_showFilterBar),
                  icon: const Icon(Icons.tune, color: Colors.white),
                  splashRadius: 24,
                ),
              ],
            ),
          ),
          if (_showFilterBar) _buildFilterPlaceholder(),
        ],
      ),
    );
  }

  // Placeholder filter row (not applying logic yet—kept simple per request)
  Widget _buildFilterPlaceholder() {
    return Container(
      alignment: Alignment.centerLeft,
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Wrap(
        spacing: 8,
        runSpacing: -4,
        children: [
          _FilterChip(
            label: 'Warehouse ${widget.currentWarehouseId}',
            selected: true,
            onSelected: (_) {},
          ),
          _FilterChip(
            label: 'Low Stock',
            selected: false,
            onSelected: (_) {},
          ),
        ],
      ),
    );
  }

  // ---------------- Search Field ----------------
  Widget _buildSearchField() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.12),
            blurRadius: 5,
            offset: const Offset(0, 2),
          )
        ],
      ),
      child: TextField(
        controller: _searchCtrl,
        textInputAction: TextInputAction.search,
        decoration: InputDecoration(
          hintText: 'Search by name or id',
          hintStyle: TextStyle(color: Colors.grey.shade500),
          prefixIcon: Icon(Icons.search, color: Colors.grey.shade600),
          suffixIcon: _searchCtrl.text.isNotEmpty
              ? IconButton(
            icon: Icon(Icons.clear, color: Colors.grey.shade600),
            splashRadius: 18,
            onPressed: () {
              _searchCtrl.clear();
              setState(() {
                _isSearching = false;
              });
            },
          )
              : null,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        ),
        onSubmitted: (_) {
          setState(() {
            _isSearching = _searchCtrl.text.trim().isNotEmpty;
          });
        },
      ),
    );
  }

  // ---------------- Tabs (non-search state) ----------------
  Widget _buildCategoryTabs() {
    return StreamBuilder<List<Category>>(
      stream: _svc.watchCategories(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _buildError('Failed to load categories: ${snapshot.error}');
        }
        if (!snapshot.hasData) {
          return _buildLoading('Loading categories...');
        }

        final categories = snapshot.data!;
        if (categories.isEmpty) {
          return _buildEmptyState('No categories found', Icons.category_outlined);
        }

        // Ensure correct length
        if (_tabController == null || _tabController!.length != categories.length + 1) {
          _tabController?.dispose();
          _tabController = TabController(length: categories.length + 1, vsync: this);
        }

        return Column(
          children: [
            Container(
              color: Colors.white,
              child: TabBar(
                controller: _tabController,
                isScrollable: true,
                labelColor: const Color(0xFFE53935),
                unselectedLabelColor: Colors.black54,
                indicatorColor: const Color(0xFFE53935),
                indicatorWeight: 3,
                labelStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                unselectedLabelStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                tabs: [
                  const Tab(text: 'All'),
                  ...categories.map((c) => Tab(text: c.name)),
                ],
              ),
            ),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildAllTab(categories),
                  ...categories.map(_buildCategoryTab),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  // "All" tab: Show top N per category (N=2) – minimal cards
  Widget _buildAllTab(List<Category> categories) {
    return RefreshIndicator(
      onRefresh: () async => setState(() {}),
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: categories.length,
        itemBuilder: (context, index) {
          final cat = categories[index];
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  '${cat.name} :',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
              ),
              StreamBuilder<List<Product>>(
                stream: _svc.watchTopProductsByCategory(cat.id, limit: 2),
                builder: (context, prodSnap) {
                  if (prodSnap.hasError) {
                    return _buildSectionError('Error loading ${cat.name}');
                  }
                  final products = prodSnap.data ?? [];
                  if (products.isEmpty) {
                    return _buildSectionEmpty('No products in ${cat.name}');
                  }
                  return GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                      childAspectRatio: 0.85,
                    ),
                    itemCount: products.length,
                    itemBuilder: (context, i) => ProductCard(
                      product: products[i],
                      layout: ProductCardLayout.minimal,
                      onTap: () => _openProduct(products[i]),
                    ),
                  );
                },
              ),
              const SizedBox(height: 28),
            ],
          );
        },
      ),
    );
  }

  // Single category tab – all products minimal
  Widget _buildCategoryTab(Category category) {
    return RefreshIndicator(
      onRefresh: () async => setState(() {}),
      child: StreamBuilder<List<Product>>(
        stream: _svc.watchProductsByCategory(category.id),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return _buildError('Error loading products: ${snapshot.error}');
          }
          if (!snapshot.hasData) {
            return _buildLoading('Loading products...');
          }
          final products = snapshot.data!;
          if (products.isEmpty) {
            return _buildEmptyState('No products in ${category.name}', Icons.inventory_2_outlined);
          }
          return GridView.builder(
            padding: const EdgeInsets.all(16),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 0.85,
            ),
            itemCount: products.length,
            itemBuilder: (context, i) => ProductCard(
              product: products[i],
              layout: ProductCardLayout.minimal,
              onTap: () => _openProduct(products[i]),
            ),
          );
        },
      ),
    );
  }

  // ---------------- Search Results (also minimal) ----------------
  Widget _buildSearchResults() {
    return StreamBuilder<List<Product>>(
      stream: _svc.watchSearchProducts(_searchCtrl.text),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _buildError('Search failed: ${snapshot.error}');
        }
        if (!snapshot.hasData) {
          return _buildLoading('Searching...');
        }
        final products = snapshot.data!;
        if (products.isEmpty) {
          return _buildEmptyState(
            'No results for "${_searchCtrl.text}"',
            Icons.search_off,
            subtitle: 'Try different keywords or check spelling',
          );
        }

        return Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              color: Colors.white,
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      '${products.length} results',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: GridView.builder(
                padding: const EdgeInsets.all(16),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: 0.85,
                ),
                itemCount: products.length,
                itemBuilder: (context, i) => ProductCard(
                  product: products[i],
                  layout: ProductCardLayout.minimal,
                  onTap: () => _openProduct(products[i]),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  // ---------------- Navigation ----------------
  void _openProduct(Product product) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ProductDetailPage(
          product: product,
          lowStockThreshold: lowStockThreshold,
        ),
      ),
    );
  }

  // ---------------- UI Helpers ----------------
  Widget _buildLoading(String label) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: 16),
          Text(label),
        ],
      ),
    );
  }

  Widget _buildError(String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 64, color: Colors.red),
            const SizedBox(height: 16),
            Text(
              'Oops! Something went wrong',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () => setState(() {}),
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFE53935),
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(String message, IconData icon, {String? subtitle}) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 64, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade600,
              ),
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 8),
              Text(
                subtitle,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey.shade500,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSectionError(String message) {
    return Container(
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.red.shade200),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline, color: Colors.red.shade600),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                color: Colors.red.shade700,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionEmpty(String message) {
    return Container(
      padding: const EdgeInsets.all(20),
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Center(
        child: Text(
          message,
          style: TextStyle(
            color: Colors.grey.shade600,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }
}

// Simple filter chip (visual only here)
class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final ValueChanged<bool> onSelected;

  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return FilterChip(
      label: Text(
        label,
        style: TextStyle(
          color: selected ? Colors.white : Colors.white70,
          fontWeight: FontWeight.w500,
          fontSize: 12,
        ),
      ),
      selected: selected,
      onSelected: onSelected,
      backgroundColor: Colors.white.withOpacity(0.2),
      selectedColor: Colors.white.withOpacity(0.35),
      checkmarkColor: Colors.white,
      side: BorderSide(color: Colors.white.withOpacity(0.3)),
    );
  }
}