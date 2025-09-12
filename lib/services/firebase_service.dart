import 'package:cloud_firestore/cloud_firestore.dart';
import '../model.dart';

class FirebaseService {
  final _db = FirebaseFirestore.instance;

  // 分类（按 order 排序）
  Stream<List<Category>> watchCategories() {
    return _db
        .collection('categories')
        .orderBy('order')
        .snapshots()
        .map((s) => s.docs.map((d) => Category.fromDoc(d.id, d.data())).toList());
  }

  // 某分类下前 N 个产品（用于首页块）
  Stream<List<Product>> watchTopProductsByCategory(String categoryId, {int limit = 2}) {
    return _db
        .collection('products')
        .where('categoryId', isEqualTo: categoryId)
        .limit(limit)
        .snapshots()
        .map((s) => s.docs.map((d) => Product.fromDoc(d.id, d.data())).toList());
  }

  // 搜索（客户端过滤：name + 文档ID + keywords）
  Stream<List<Product>> watchSearchProducts(String keyword) {
    final k = keyword.trim().toLowerCase();
    return _db.collection('products').snapshots().map((s) {
      final all = s.docs.map((d) => Product.fromDoc(d.id, d.data())).toList();
      if (k.isEmpty) return all;
      return all.where((p) {
        final hay = [p.id, p.name, ...p.keywords].join(' ').toLowerCase();
        return hay.contains(k);
      }).toList();
    });
  }

  // 所有仓库
  Stream<List<Warehouse>> watchWarehouses() {
    return _db.collection('warehouses').orderBy('code').snapshots().map(
          (s) => s.docs.map((d) => Warehouse.fromDoc(d.id, d.data())).toList(),
    );
  }

  /// 读取某产品在各仓库的库存
  /// stocks 文档 ID 形如："{warehouseCode}_{productId}"，例如 A_BR001
  Stream<Map<Warehouse, List<StockEntry>>> watchProductStocksAcrossWarehouses(
      Product product) {
    final whStream = watchWarehouses();
    return whStream.asyncMap((warehouses) async {
      final result = <Warehouse, List<StockEntry>>{};
      for (final w in warehouses) {
        final docId = '${w.code}_${product.id}';
        final doc = await _db.collection('stocks').doc(docId).get();
        if (!doc.exists) continue;
        final data = doc.data() as Map<String, dynamic>? ?? {};
        final locs = (data['locations'] as List?)?.cast<Map<String, dynamic>>() ?? const [];
        final entries = locs
            .map((m) => StockEntry.fromMap(m))
            .where((e) => e.productId == product.id) // 保险过滤
            .toList();
        if (entries.isNotEmpty) result[w] = entries;
      }
      return result;
    });
  }
}
