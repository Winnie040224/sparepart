class Category {
  final String id;     // 文档ID，如 body_exterior
  final String name;   // "Body & Exterior"
  final int order;     // 排序

  Category({required this.id, required this.name, required this.order});

  factory Category.fromDoc(String id, Map<String, dynamic> d) => Category(
    id: id,
    name: d['name'] ?? '',
    order: (d['order'] as num?)?.toInt() ?? 999,
  );
}

class Product {
  final String id;          // 文档ID，如 BE001
  final String name;        // "Side Mirror"
  final String categoryId;  // "body_exterior"
  final String imageName;   // "side_mirror.jpg"
  final List<String> keywords;

  Product({
    required this.id,
    required this.name,
    required this.categoryId,
    required this.imageName,
    required this.keywords,
  });

  factory Product.fromDoc(String id, Map<String, dynamic> d) => Product(
    id: id,
    name: d['name'] ?? '',
    categoryId: d['categoryId'] ?? '',
    imageName: d['imageName'] ?? 'placeholder.png',
    keywords:
    (d['searchKeywords'] as List?)?.map((e) => '$e').toList() ?? const [],
  );

  String get assetPath => 'assets/images/$imageName';
}

class Warehouse {
  final String id;   // 文档ID：A / B / C
  final String code; // "A"
  final String name; // "Warehouse A"
  Warehouse({required this.id, required this.code, required this.name});

  factory Warehouse.fromDoc(String id, Map<String, dynamic> d) =>
      Warehouse(id: id, code: d['code'] ?? id, name: d['name'] ?? id);
}

class StockEntry {
  final String bay;
  final int quantity;
  final double price;
  final String warehouseId; // "A"
  final String productId;   // "BR001"
  final String productName; // "Brake Pad"

  StockEntry({
    required this.bay,
    required this.quantity,
    required this.price,
    required this.warehouseId,
    required this.productId,
    required this.productName,
  });

  factory StockEntry.fromMap(Map<String, dynamic> m) => StockEntry(
    bay: m['bay'] ?? '',
    quantity: (m['quantity'] as num?)?.toInt() ?? 0,
    price: (m['price'] as num?)?.toDouble() ?? 0.0,
    warehouseId: m['warehouseId'] ?? '',
    productId: m['productId'] ?? '',
    productName: m['productName'] ?? '',
  );
}
