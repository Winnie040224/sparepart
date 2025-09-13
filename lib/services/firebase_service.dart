import 'package:cloud_firestore/cloud_firestore.dart';
import '../model.dart';

class FirebaseService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // ---------------- Categories ----------------
  Stream<List<Category>> watchCategories() {
    return _db
        .collection('categories')
        .orderBy('order')
        .snapshots()
        .map((snap) => snap.docs.map(Category.fromDoc).toList());
  }

  Future<Category?> getCategory(String id) async {
    final doc = await _db.collection('categories').doc(id).get();
    if (!doc.exists) return null;
    return Category.fromDoc(doc);
  }

  // ---------------- Internal helpers ----------------
  Future<List<Stock>> _fetchStocksForProductId(String productId) async {
    final qs = await _db
        .collection('stocks')
        .where('productId', isEqualTo: productId)
        .get();
    return qs.docs.map(Stock.fromDoc).toList();
  }

  // Build a Product from its Firestore product doc + its stocks
  Future<Product> _buildProduct(DocumentSnapshot prodDoc) async {
    final stocks = await _fetchStocksForProductId(prodDoc.id);
    return Product.fromProductDoc(prodDoc, stocks);
  }

  // ---------------- Single Product ----------------
  Stream<Product?> watchProduct(String productId) {
    return _db.collection('products').doc(productId).snapshots().asyncMap(
          (doc) async {
        if (!doc.exists) return null;
        return _buildProduct(doc);
      },
    );
  }

  Future<Product?> getProduct(String productId) async {
    final doc = await _db.collection('products').doc(productId).get();
    if (!doc.exists) return null;
    return _buildProduct(doc);
  }

  // ---------------- Products by Category ----------------
  Stream<List<Product>> watchProductsByCategory(String categoryId) {
    return _db
        .collection('products')
        .where('categoryId', isEqualTo: categoryId)
        .snapshots()
        .asyncMap((snap) async {
      final futures = snap.docs.map(_buildProduct).toList();
      return Future.wait(futures);
    });
  }

  Stream<List<Product>> watchTopProductsByCategory(String categoryId,
      {int limit = 2}) {
    return _db
        .collection('products')
        .where('categoryId', isEqualTo: categoryId)
        .limit(limit)
        .snapshots()
        .asyncMap((snap) async {
      final futures = snap.docs.map(_buildProduct).toList();
      return Future.wait(futures);
    });
  }

  // ---------------- Search ----------------
  // Client-side filtering. Returns all products first, then filters if keyword not empty.
  Stream<List<Product>> watchSearchProducts(String keyword) {
    final k = keyword.trim().toLowerCase();

    return _db.collection('products').snapshots().asyncMap((snap) async {
      final futures = snap.docs.map(_buildProduct).toList();
      final all = await Future.wait(futures);
      if (k.isEmpty) return all;

      return all.where((p) {
        final hay = [
          p.docId,
          p.name,
          ...p.searchKeywords,
        ].join(' ').toLowerCase();
        return hay.contains(k);
      }).toList();
    });
  }

  // ---------------- Warehouses ----------------
  Stream<List<Warehouse>> watchWarehouses() {
    return _db
        .collection('warehouses')
        .orderBy('code')
        .snapshots()
        .map((snap) => snap.docs.map(Warehouse.fromDoc).toList());
  }

  Future<Warehouse?> getWarehouse(String code) async {
    final doc = await _db.collection('warehouses').doc(code).get();
    if (!doc.exists) return null;
    return Warehouse.fromDoc(doc);
  }

  // ---------------- Stocks (direct) ----------------
  // stock doc id pattern might be {warehouseCode}_{productId} in your data, but you also use auto IDs sometimes.
  Future<Stock?> getStockDoc(String stockDocId) async {
    final doc = await _db.collection('stocks').doc(stockDocId).get();
    if (!doc.exists) return null;
    return Stock.fromDoc(doc);
  }

  Stream<Stock?> watchStockDoc(String stockDocId) {
    return _db
        .collection('stocks')
        .doc(stockDocId)
        .snapshots()
        .map((d) => d.exists ? Stock.fromDoc(d) : null);
  }

  Stream<List<Stock>> watchStocksForProduct(String productId) {
    return _db
        .collection('stocks')
        .where('productId', isEqualTo: productId)
        .snapshots()
        .map((snap) => snap.docs.map(Stock.fromDoc).toList());
  }

  Stream<List<Stock>> watchStocksInWarehouse(String warehouseCode) {
    return _db
        .collection('stocks')
        .where('warehouseId', isEqualTo: warehouseCode)
        .snapshots()
        .map((snap) => snap.docs.map(Stock.fromDoc).toList());
  }

  Stream<List<Stock>> watchLowStock({int threshold = 50}) {
    return _db.collection('stocks').snapshots().map((snap) {
      final list = snap.docs
          .map(Stock.fromDoc)
          .where((sd) => sd.totalQuantity < threshold)
          .toList();
      return list;
    });
  }

  // ---------------- Mutations ----------------
  // Create OR append a new location to a stock doc keyed by warehouseCode_productId
  Future<bool> createOrAppendStock({
    required String warehouseCode,
    required String productId,
    required String productName,
    required String categoryId,
    required double price,
    required String bay,
    required int quantity,
  }) async {
    try {
      final id = '${warehouseCode}_$productId';
      final ref = _db.collection('stocks').doc(id);
      final snap = await ref.get();
      if (!snap.exists) {
        await ref.set({
          'warehouseId': warehouseCode,
          'productId': productId,
          'productName': productName,
          'categoryId': categoryId,
          'price': price,
          'locations': [
            {'bay': bay, 'quantity': quantity}
          ],
          'createdAt': FieldValue.serverTimestamp(),
        });
      } else {
        final data = snap.data() as Map<String, dynamic>;
        final locs =
            (data['locations'] as List?)?.cast<Map<String, dynamic>>() ?? [];
        locs.add({'bay': bay, 'quantity': quantity});
        await ref.update({'locations': locs, 'price': price});
      }
      return true;
    } catch (e) {
      print('createOrAppendStock error: $e');
      return false;
    }
  }

  Future<bool> updateLocationQuantity({
    required String stockDocId,
    required int locationIndex,
    required int newQuantity,
  }) async {
    try {
      final ref = _db.collection('stocks').doc(stockDocId);
      final snap = await ref.get();
      if (!snap.exists) return false;
      final data = snap.data() as Map<String, dynamic>;
      final locs =
          (data['locations'] as List?)?.cast<Map<String, dynamic>>() ?? [];
      if (locationIndex < 0 || locationIndex >= locs.length) return false;
      locs[locationIndex]['quantity'] = newQuantity;
      await ref.update({'locations': locs});
      return true;
    } catch (e) {
      print('updateLocationQuantity error: $e');
      return false;
    }
  }

  Future<bool> addLocation({
    required String stockDocId,
    required String bay,
    required int quantity,
  }) async {
    try {
      final ref = _db.collection('stocks').doc(stockDocId);
      final snap = await ref.get();
      if (!snap.exists) return false;
      final data = snap.data() as Map<String, dynamic>;
      final locs =
          (data['locations'] as List?)?.cast<Map<String, dynamic>>() ?? [];
      locs.add({'bay': bay, 'quantity': quantity});
      await ref.update({'locations': locs});
      return true;
    } catch (e) {
      print('addLocation error: $e');
      return false;
    }
  }

  Future<bool> removeLocation({
    required String stockDocId,
    required int locationIndex,
  }) async {
    try {
      final ref = _db.collection('stocks').doc(stockDocId);
      final snap = await ref.get();
      if (!snap.exists) return false;
      final data = snap.data() as Map<String, dynamic>;
      final locs =
          (data['locations'] as List?)?.cast<Map<String, dynamic>>() ?? [];
      if (locationIndex < 0 || locationIndex >= locs.length) return false;
      locs.removeAt(locationIndex);
      await ref.update({'locations': locs});
      return true;
    } catch (e) {
      print('removeLocation error: $e');
      return false;
    }
  }

  Future<bool> updateStockPrice({
    required String stockDocId,
    required double newPrice,
  }) async {
    try {
      await _db.collection('stocks').doc(stockDocId).update({'price': newPrice});
      return true;
    } catch (e) {
      print('updateStockPrice error: $e');
      return false;
    }
  }

  // Debug helper
  Future<void> debugLogProduct(String productId) async {
    final p = await getProduct(productId);
    print('[DEBUG product] $productId -> imageName=${p?.imageName}');
    final stocks = await _db
        .collection('stocks')
        .where('productId', isEqualTo: productId)
        .get();
    for (final d in stocks.docs) {
      final sd = Stock.fromDoc(d);
      print(
          ' stockDoc=${sd.docId} wh=${sd.warehouseId} total=${sd.totalQuantity} price=${sd.price} locs=${sd.locations.length}');
    }
  }
}