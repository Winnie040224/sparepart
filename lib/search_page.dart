import 'package:flutter/material.dart';
import 'model.dart';
import 'services/firebase_service.dart';
import 'product_card.dart';
import 'section_title.dart';
import 'product_stock_page.dart';

class SearchPage extends StatefulWidget {
  final String currentWarehouseId; // e.g. "A"
  const SearchPage({super.key, required this.currentWarehouseId});

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  final _svc = FirebaseService();
  final _searchCtrl = TextEditingController();

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final themeRed = const Color(0xFFE53935);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: themeRed,
        title: const Text('Search'),
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              controller: _searchCtrl,
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.search),
                hintText: 'Search by name or id',
                filled: true,
                fillColor: Colors.grey[200],
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                contentPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
              onChanged: (_) => setState(() {}),
            ),
          ),

          Expanded(
            child: StreamBuilder<List<Category>>(
              stream: _svc.watchCategories(),
              builder: (context, snap) {
                if (snap.hasError) {
                  return Center(child: Text('Error: ${snap.error}'));
                }
                if (!snap.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final cats = snap.data!;
                final length = cats.isEmpty ? 1 : cats.length + 1;

                return DefaultTabController(
                  length: length,
                  child: Column(
                    children: [
                      TabBar(
                        isScrollable: true,
                        labelColor: themeRed,
                        unselectedLabelColor: Colors.black87,
                        indicatorColor: themeRed,
                        tabs: [
                          const Tab(text: 'All'),
                          ...cats.map((c) => Tab(text: c.name)),
                        ],
                      ),
                      Expanded(
                        child: _searchCtrl.text.trim().isNotEmpty
                            ? _buildSearchResults()
                            : TabBarView(
                          children: [
                            _buildAll(cats),
                            ...cats.map(_buildCategorySection),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // All：按分类分段，每段最多 2 个产品
  Widget _buildAll(List<Category> cats) {
    if (cats.isEmpty) return const Center(child: Text('No categories'));
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: cats.length,
      itemBuilder: (_, i) {
        final c = cats[i];
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SectionTitle('${c.name} :'),
            StreamBuilder<List<Product>>(
              stream: _svc.watchTopProductsByCategory(c.id, limit: 2),
              builder: (context, snap) {
                if (snap.hasError) {
                  return Text('Error: ${snap.error}');
                }
                final prods = snap.data ?? [];
                return GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    childAspectRatio: .95,
                  ),
                  itemCount: prods.length,
                  itemBuilder: (_, j) => ProductCard(
                    product: prods[j],
                    onTap: () => _openProduct(prods[j]),
                  ),
                );
              },
            ),
            const SizedBox(height: 8),
          ],
        );
      },
    );
  }

  // 单分类 Tab：最多 2 个产品
  Widget _buildCategorySection(Category c) {
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        SectionTitle('${c.name} :'),
        StreamBuilder<List<Product>>(
          stream: _svc.watchTopProductsByCategory(c.id, limit: 2),
          builder: (context, snap) {
            if (snap.hasError) return Text('Error: ${snap.error}');
            final prods = snap.data ?? [];
            if (prods.isEmpty) return const Text('No products');
            return GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: .95,
              ),
              itemCount: prods.length,
              itemBuilder: (_, j) => ProductCard(
                product: prods[j],
                onTap: () => _openProduct(prods[j]),
              ),
            );
          },
        ),
      ],
    );
  }

  // 搜索结果
  Widget _buildSearchResults() {
    return StreamBuilder<List<Product>>(
      stream: _svc.watchSearchProducts(_searchCtrl.text),
      builder: (context, snap) {
        if (snap.hasError) return Center(child: Text('Error: ${snap.error}'));
        final prods = snap.data ?? [];
        if (prods.isEmpty) return const Center(child: Text('No results'));
        return GridView.builder(
          padding: const EdgeInsets.all(12),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: .95,
          ),
          itemCount: prods.length,
          itemBuilder: (_, i) =>
              ProductCard(product: prods[i], onTap: () => _openProduct(prods[i])),
        );
      },
    );
  }

  void _openProduct(Product p) {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => ProductStockPage(
        product: p,
        currentWarehouseId: widget.currentWarehouseId,
      ),
    ));
  }
}
