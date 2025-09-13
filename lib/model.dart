import 'package:cloud_firestore/cloud_firestore.dart';

class Category {
  final String id;
  final String name;
  final int order;

  Category({
    required this.id,
    required this.name,
    required this.order,
  });

  factory Category.fromDoc(DocumentSnapshot d) {
    final m = d.data() as Map<String, dynamic>? ?? {};
    return Category(
      id: d.id,
      name: m['name'] ?? '',
      order: m['order'] ?? 0,
    );
  }
}

class Warehouse {
  final String code;
  final String name;

  Warehouse({
    required this.code,
    required this.name,
  });

  factory Warehouse.fromDoc(DocumentSnapshot d) {
    final m = d.data() as Map<String, dynamic>? ?? {};
    return Warehouse(
      code: m['code'] ?? d.id,
      name: m['name'] ?? '',
    );
  }
}

class StockLocation {
  final String bay;
  final int quantity;

  StockLocation({
    required this.bay,
    required this.quantity,
  });

  factory StockLocation.fromMap(Map<String, dynamic> data) {
    return StockLocation(
      bay: data['bay'] ?? '',
      quantity: (data['quantity'] ?? 0) is int
          ? data['quantity'] ?? 0
          : (data['quantity'] as num).toInt(),
    );
  }
}

class Stock {
  final String docId;
  final String categoryId;
  final String productId;
  final String productName;
  final String warehouseId;
  final double price;
  final List<StockLocation> locations;

  Stock({
    required this.docId,
    required this.categoryId,
    required this.productId,
    required this.productName,
    required this.warehouseId,
    required this.price,
    required this.locations,
  });

  factory Stock.fromDoc(DocumentSnapshot d) {
    final m = d.data() as Map<String, dynamic>? ?? {};

    // Parse locations array
    final locationsList = <StockLocation>[];
    final locationsData = m['locations'] as List<dynamic>? ?? [];
    for (final locationData in locationsData) {
      if (locationData is Map<String, dynamic>) {
        locationsList.add(StockLocation.fromMap(locationData));
      }
    }

    return Stock(
      docId: d.id,
      categoryId: m['categoryId'] ?? '',
      productId: m['productId'] ?? '',
      productName: m['productName'] ?? '',
      warehouseId: m['warehouseId'] ?? '',
      price: (m['price'] ?? 0.0) is int
          ? (m['price'] ?? 0).toDouble()
          : (m['price'] ?? 0.0) + 0.0,
      locations: locationsList,
    );
  }

  // Helper methods
  int get totalQuantity => locations.fold<int>(0, (sum, loc) => sum + loc.quantity);

  bool get hasStock => totalQuantity > 0;

  String get primaryBay => locations.isNotEmpty ? locations.first.bay : '';
}

class Product {
  final String docId;
  final String categoryId;
  final String imageName;
  final String name;
  final List<String> searchKeywords;
  final List<Stock> stocks;

  Product({
    required this.docId,
    required this.categoryId,
    required this.imageName,
    required this.name,
    required this.searchKeywords,
    required this.stocks,
  });

  factory Product.fromProductDoc(DocumentSnapshot d, List<Stock> relatedStocks) {
    final m = d.data() as Map<String, dynamic>? ?? {};

    return Product(
      docId: d.id,
      categoryId: m['categoryId'] ?? '',
      imageName: m['imageName'] ?? 'placeholder.png',
      name: m['name'] ?? '',
      searchKeywords: List<String>.from(m['searchKeywords'] ?? []),
      stocks: relatedStocks,
    );
  }

  // FIXED: Remove the duplicate "assets" from the path
  String get imageAssetPath {
    if (imageName.isEmpty) return '';
    // Make sure we don't have double "assets" in the path
    return 'assets/images/$imageName';
  }

  int totalQty() => stocks.fold<int>(0, (sum, s) => sum + s.totalQuantity);

  double get averagePrice {
    if (stocks.isEmpty) return 0.0;
    final totalPrice = stocks.fold<double>(0.0, (sum, s) => sum + s.price);
    return totalPrice / stocks.length;
  }

  Stock? stockFor(String warehouseId) {
    try {
      return stocks.firstWhere((s) => s.warehouseId == warehouseId);
    } catch (e) {
      return null;
    }
  }

  bool get hasStock => totalQty() > 0;

  String get categoryName => categoryId.replaceAll('_', ' ').toUpperCase();

  // Get unique warehouses where this product is available
  List<String> get warehouseIds => stocks.map((s) => s.warehouseId).toSet().toList();
}