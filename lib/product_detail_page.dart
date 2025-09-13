import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'model.dart';
import 'product_stock_page.dart';
import 'services/firebase_service.dart';

class ProductDetailPage extends StatefulWidget {
  final Product product;
  final int lowStockThreshold;

  const ProductDetailPage({
    super.key,
    required this.product,
    this.lowStockThreshold = 50,
  });

  @override
  State<ProductDetailPage> createState() => _ProductDetailPageState();
}

class _ProductDetailPageState extends State<ProductDetailPage>
    with SingleTickerProviderStateMixin {
  final _svc = FirebaseService();
  late AnimationController _animController;
  late Animation<double> _fadeAnimation;
  bool _isFavorite = false;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeInOut),
    );
    _animController.forward();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final themeRed = const Color(0xFFE53935);
    final isLowStock = widget.product.totalQty() < widget.lowStockThreshold;

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      body: CustomScrollView(
        slivers: [
          // Custom App Bar with Hero Image
          SliverAppBar(
            expandedHeight: 300,
            pinned: true,
            backgroundColor: themeRed,
            foregroundColor: Colors.white,
            title: FadeTransition(
              opacity: _fadeAnimation,
              child: Text(
                widget.product.name,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
            actions: [
              IconButton(
                onPressed: _toggleFavorite,
                icon: Icon(
                  _isFavorite ? Icons.favorite : Icons.favorite_border,
                  color: _isFavorite ? Colors.pink : Colors.white,
                ),
              ),
              IconButton(
                onPressed: _shareProduct,
                icon: const Icon(Icons.share),
              ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      themeRed.withValues(alpha: 0.8),
                      themeRed,
                    ],
                  ),
                ),
                child: Center(
                  child: Hero(
                    tag: 'product-${widget.product.docId}',
                    child: Container(
                      width: 200,
                      height: 200,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.2),
                            blurRadius: 20,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: _buildProductImage(),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),

          // Product Details Content
          SliverToBoxAdapter(
            child: StreamBuilder<Product?>(
              stream: _svc.watchProduct(widget.product.docId),
              builder: (context, snapshot) {
                final product = snapshot.data ?? widget.product;

                return FadeTransition(
                  opacity: _fadeAnimation,
                  child: Column(
                    children: [
                      // Basic Info Card
                      _buildBasicInfoCard(product, isLowStock, themeRed),

                      // Stock Summary Card
                      _buildStockSummaryCard(product, themeRed),

                      // Warehouse Details Card
                      _buildWarehouseDetailsCard(product, themeRed),

                      // Action Buttons
                      _buildActionButtons(product, themeRed),

                      const SizedBox(height: 100), // Bottom padding
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

  Widget _buildProductImage() {
    if (widget.product.imageName.isEmpty) {
      return Container(
        color: Colors.grey.shade200,
        child: const Center(
          child: Icon(Icons.image, size: 80, color: Colors.grey),
        ),
      );
    }

    return Image.asset(
      widget.product.imageAssetPath,
      fit: BoxFit.cover,
      errorBuilder: (context, error, stackTrace) {
        return Container(
          color: Colors.grey.shade200,
          child: const Center(
            child: Icon(Icons.broken_image, size: 80, color: Colors.grey),
          ),
        );
      },
    );
  }

  Widget _buildBasicInfoCard(Product product, bool isLowStock, Color themeRed) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      product.name,
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'ID: ${product.docId}',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey.shade600,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              if (isLowStock)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: themeRed,
                    borderRadius: BorderRadius.circular(25),
                    boxShadow: [
                      BoxShadow(
                        color: themeRed.withValues(alpha: 0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: const Text(
                    'LOW STOCK',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 20),

          // Product Specs
          _buildSpecGrid([
            SpecItem('Category', product.categoryName, Icons.category),
            SpecItem('Total Stock', '${product.totalQty()} units', Icons.inventory_2),
            SpecItem('Avg Price', 'RM ${product.averagePrice.toStringAsFixed(2)}', Icons.attach_money),
            SpecItem('Warehouses', '${product.warehouseIds.length}', Icons.warehouse),
          ]),
        ],
      ),
    );
  }

  Widget _buildStockSummaryCard(Product product, Color themeRed) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.analytics_outlined, color: themeRed, size: 24),
              const SizedBox(width: 12),
              const Text(
                'Stock Overview',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          if (product.stocks.isNotEmpty) ...[
            // Stock bars for each warehouse
            ...product.stocks.map((stock) {
              final percentage = product.totalQty() > 0
                  ? (stock.totalQuantity / product.totalQty())
                  : 0.0;
              final isLow = stock.totalQuantity < widget.lowStockThreshold;

              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Warehouse ${stock.warehouseId}',
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                        ),
                        Text(
                          '${stock.totalQuantity} units',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: isLow ? themeRed : Colors.green.shade600,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    LinearProgressIndicator(
                      value: percentage,
                      backgroundColor: Colors.grey.shade200,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        isLow ? themeRed : Colors.green.shade600,
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ] else
            const Text('No stock data available'),
        ],
      ),
    );
  }

  Widget _buildWarehouseDetailsCard(Product product, Color themeRed) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.location_on_outlined, color: themeRed, size: 24),
              const SizedBox(width: 12),
              const Text(
                'Warehouse Details',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              const Spacer(),
              TextButton(
                onPressed: () => _openStockPage(product),
                child: Text(
                  'View All',
                  style: TextStyle(color: themeRed, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          if (product.stocks.isNotEmpty) ...[
            ...product.stocks.take(3).map((stock) {
              final isLow = stock.totalQuantity < widget.lowStockThreshold;

              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isLow ? themeRed.withValues(alpha: 0.3) : Colors.grey.shade200,
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: isLow ? themeRed.withValues(alpha: 0.1) : Colors.blue.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Center(
                        child: Text(
                          stock.warehouseId,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: isLow ? themeRed : Colors.blue,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            stock.primaryBay.isNotEmpty ? stock.primaryBay : 'No bay assigned',
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                            ),
                          ),
                          Text(
                            '${stock.totalQuantity} units • RM ${stock.price.toStringAsFixed(2)}',
                            style: TextStyle(
                              color: Colors.grey.shade600,
                              fontSize: 12,
                            ),
                          ),
                          if (stock.locations.length > 1)
                            Text(
                              '${stock.locations.length} locations',
                              style: TextStyle(
                                color: Colors.grey.shade500,
                                fontSize: 11,
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                        ],
                      ),
                    ),
                    if (isLow)
                      Icon(Icons.warning_amber_rounded, color: themeRed, size: 20),
                  ],
                ),
              );
            }).toList(),

            if (product.stocks.length > 3)
              Center(
                child: Text(
                  '+ ${product.stocks.length - 3} more warehouses',
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
          ] else
            const Text('No warehouse data available'),
        ],
      ),
    );
  }

  Widget _buildActionButtons(Product product, Color themeRed) {
    return Container(
      margin: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Primary Actions
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => _openStockPage(product),
                  icon: const Icon(Icons.inventory_2),
                  label: const Text('View Stock Details'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: themeRed,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Secondary Actions
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _requestRestock,
                  icon: const Icon(Icons.add_circle_outline),
                  label: const Text('Request Restock'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: themeRed,
                    side: BorderSide(color: themeRed),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _editProduct,
                  icon: const Icon(Icons.edit),
                  label: const Text('Edit Product'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.grey.shade700,
                    side: BorderSide(color: Colors.grey.shade300),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSpecGrid(List<SpecItem> specs) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 3,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemCount: specs.length,
      itemBuilder: (context, index) {
        final spec = specs[index];
        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.grey.shade50,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Row(
            children: [
              Icon(spec.icon, size: 20, color: Colors.grey.shade600),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      spec.label,
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey.shade600,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Text(
                      spec.value,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _toggleFavorite() {
    setState(() {
      _isFavorite = !_isFavorite;
    });

    HapticFeedback.lightImpact();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(_isFavorite ? 'Added to favorites' : 'Removed from favorites'),
        duration: const Duration(seconds: 1),
      ),
    );
  }

  void _shareProduct() {
    HapticFeedback.selectionClick();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Share functionality coming soon')),
    );
  }

  void _openStockPage(Product product) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ProductStockPage(
          product: product,
          currentWarehouseId: 'A', // You can pass the actual current warehouse
          lowStockThreshold: widget.lowStockThreshold,
        ),
      ),
    );
  }

  void _requestRestock() {
    HapticFeedback.lightImpact();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Request Restock'),
        content: const Text('This will send a restock request to the warehouse manager.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Restock request sent')),
              );
            },
            child: const Text('Send Request'),
          ),
        ],
      ),
    );
  }

  void _editProduct() {
    HapticFeedback.selectionClick();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Edit functionality coming soon')),
    );
  }
}

class SpecItem {
  final String label;
  final String value;
  final IconData icon;

  SpecItem(this.label, this.value, this.icon);
}