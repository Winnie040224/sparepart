import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'model.dart';
import 'services/firebase_service.dart';

class ProductStockPage extends StatefulWidget {
  final Product product;
  final String currentWarehouseId;
  final int lowStockThreshold;

  const ProductStockPage({
    super.key,
    required this.product,
    required this.currentWarehouseId,
    this.lowStockThreshold = 50,
  });

  @override
  State<ProductStockPage> createState() => _ProductStockPageState();
}

class _ProductStockPageState extends State<ProductStockPage>
    with SingleTickerProviderStateMixin {
  final _svc = FirebaseService();
  late AnimationController _animController;
  late Animation<double> _slideAnimation;
  String _sortBy = 'warehouse'; // 'warehouse', 'quantity', 'price'
  bool _showOnlyLowStock = false;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    _slideAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeOutCubic),
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

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        backgroundColor: themeRed,
        foregroundColor: Colors.white,
        title: const Text('Stock Availability'),
        elevation: 0,
        actions: [
          IconButton(
            onPressed: _showSortOptions,
            icon: const Icon(Icons.sort),
          ),
          IconButton(
            onPressed: _showFilterOptions,
            icon: const Icon(Icons.filter_list),
          ),
        ],
      ),
      body: StreamBuilder<Product?>(
        stream: _svc.watchProduct(widget.product.docId),
        builder: (context, snapshot) {
          final product = snapshot.data ?? widget.product;

          return Column(
            children: [
              // Product Header
              _buildProductHeader(product, themeRed),

              // Filter/Sort Bar
              if (_showOnlyLowStock || _sortBy != 'warehouse')
                _buildFilterBar(themeRed),

              // Stock List
              Expanded(
                child: _buildStockList(product, themeRed),
              ),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: themeRed,
        onPressed: _showRestockDialog,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  Widget _buildProductHeader(Product product, Color themeRed) {
    return Container(
      color: themeRed,
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, -0.5),
          end: Offset.zero,
        ).animate(_slideAnimation),
        child: FadeTransition(
          opacity: _slideAnimation,
          child: Row(
            children: [
              // Product Image
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.1),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: product.imageName.isNotEmpty
                      ? Image.asset(
                    product.imageAssetPath,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return const Icon(Icons.image, color: Colors.grey);
                    },
                  )
                      : const Icon(Icons.image, color: Colors.grey),
                ),
              ),
              const SizedBox(width: 16),

              // Product Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      product.name,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'ID: ${product.docId}',
                      style: const TextStyle(
                        fontSize: 14,
                        color: Colors.white70,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        'Total: ${product.totalQty()} units',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFilterBar(Color themeRed) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: Colors.white,
      child: Row(
        children: [
          if (_showOnlyLowStock) ...[
            Chip(
              label: const Text('Low Stock Only'),
              onDeleted: () => setState(() => _showOnlyLowStock = false),
              backgroundColor: themeRed.withValues(alpha: 0.1),
              labelStyle: TextStyle(color: themeRed),
              deleteIconColor: themeRed,
            ),
            const SizedBox(width: 8),
          ],
          if (_sortBy != 'warehouse') ...[
            Chip(
              label: Text('Sorted by ${_sortBy.capitalize()}'),
              onDeleted: () => setState(() => _sortBy = 'warehouse'),
              backgroundColor: Colors.blue.withValues(alpha: 0.1),
              labelStyle: const TextStyle(color: Colors.blue),
              deleteIconColor: Colors.blue,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStockList(Product product, Color themeRed) {
    var stocks = List<Stock>.from(product.stocks);

    // Apply filters
    if (_showOnlyLowStock) {
      stocks = stocks.where((stock) =>
      stock.totalQuantity < widget.lowStockThreshold
      ).toList();
    }

    // Apply sorting
    switch (_sortBy) {
      case 'quantity':
        stocks.sort((a, b) => b.totalQuantity.compareTo(a.totalQuantity));
        break;
      case 'price':
        stocks.sort((a, b) => a.price.compareTo(b.price));
        break;
      case 'warehouse':
      default:
        stocks.sort((a, b) => a.warehouseId.compareTo(b.warehouseId));
        break;
    }

    if (stocks.isEmpty) {
      return _buildEmptyState();
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: stocks.length,
      itemBuilder: (context, index) {
        final stock = stocks[index];
        final isCurrentWarehouse = stock.warehouseId == widget.currentWarehouseId;
        final isLowStock = stock.totalQuantity < widget.lowStockThreshold;

        return SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(1, 0),
            end: Offset.zero,
          ).animate(CurvedAnimation(
            parent: _animController,
            curve: Interval(
              index * 0.1,
              (index * 0.1) + 0.3,
              curve: Curves.easeOutCubic,
            ),
          )),
          child: WarehouseStockCard(
            stock: stock,
            isCurrentWarehouse: isCurrentWarehouse,
            isLowStock: isLowStock,
            themeRed: themeRed,
            onRestock: () => _showRestockDialog(stock: stock),
            onEdit: () => _showEditDialog(stock),
          ),
        );
      },
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.inventory_2_outlined,
            size: 64,
            color: Colors.grey.shade400,
          ),
          const SizedBox(height: 16),
          Text(
            _showOnlyLowStock ? 'No low stock items' : 'No stock data available',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey.shade600,
              fontWeight: FontWeight.w500,
            ),
          ),
          if (_showOnlyLowStock) ...[
            const SizedBox(height: 8),
            Text(
              'All warehouses have sufficient stock',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade500,
              ),
            ),
          ],
        ],
      ),
    );
  }

  void _showSortOptions() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Sort by',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            SortOption(
              title: 'Warehouse',
              isSelected: _sortBy == 'warehouse',
              onTap: () {
                setState(() => _sortBy = 'warehouse');
                Navigator.pop(context);
              },
            ),
            SortOption(
              title: 'Quantity (High to Low)',
              isSelected: _sortBy == 'quantity',
              onTap: () {
                setState(() => _sortBy = 'quantity');
                Navigator.pop(context);
              },
            ),
            SortOption(
              title: 'Price (Low to High)',
              isSelected: _sortBy == 'price',
              onTap: () {
                setState(() => _sortBy = 'price');
                Navigator.pop(context);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showFilterOptions() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Filter Options',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            SwitchListTile(
              title: const Text('Show only low stock'),
              subtitle: Text('Below ${widget.lowStockThreshold} units'),
              value: _showOnlyLowStock,
              onChanged: (value) {
                setState(() => _showOnlyLowStock = value);
                Navigator.pop(context);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showRestockDialog({Stock? stock}) {
    final stocksToRestock = stock != null ? [stock] : widget.product.stocks;
    final controllers = <String, TextEditingController>{};

    for (final s in stocksToRestock) {
      controllers[s.docId] = TextEditingController();
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Restock ${stock != null ? 'Warehouse ${stock.warehouseId}' : 'All Warehouses'}'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: controllers.entries.map((entry) {
              final stockDoc = stocksToRestock.firstWhere((s) => s.docId == entry.key);
              return Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: TextField(
                  controller: entry.value,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: 'Add to Warehouse ${stockDoc.warehouseId}',
                    border: const OutlineInputBorder(),
                    suffixText: 'units',
                    helperText: 'Current: ${stockDoc.totalQuantity} units',
                  ),
                ),
              );
            }).toList(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              HapticFeedback.heavyImpact();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Restock request submitted')),
              );
            },
            child: const Text('Submit'),
          ),
        ],
      ),
    );

    // Dispose controllers after dialog
    Future.delayed(const Duration(seconds: 1), () {
      for (final controller in controllers.values) {
        controller.dispose();
      }
    });
  }

  void _showEditDialog(Stock stock) {
    final priceController = TextEditingController(text: stock.price.toString());
    final locationControllers = <int, Map<String, TextEditingController>>{};

    for (int i = 0; i < stock.locations.length; i++) {
      final location = stock.locations[i];
      locationControllers[i] = {
        'bay': TextEditingController(text: location.bay),
        'quantity': TextEditingController(text: location.quantity.toString()),
      };
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Edit Warehouse ${stock.warehouseId}'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: priceController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Price per unit',
                  border: OutlineInputBorder(),
                  prefixText: 'RM ',
                ),
              ),
              const SizedBox(height: 16),
              const Text('Locations:', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              ...locationControllers.entries.map((entry) {
                final index = entry.key;
                final controllers = entry.value;
                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade300),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    children: [
                      TextField(
                        controller: controllers['bay']!,
                        decoration: InputDecoration(
                          labelText: 'Bay Location ${index + 1}',
                          border: const OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: controllers['quantity']!,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Quantity',
                          border: OutlineInputBorder(),
                          suffixText: 'units',
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Changes saved')),
              );
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }
}

class WarehouseStockCard extends StatelessWidget {
  final Stock stock;
  final bool isCurrentWarehouse;
  final bool isLowStock;
  final Color themeRed;
  final VoidCallback onRestock;
  final VoidCallback onEdit;

  const WarehouseStockCard({
    super.key,
    required this.stock,
    required this.isCurrentWarehouse,
    required this.isLowStock,
    required this.themeRed,
    required this.onRestock,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isCurrentWarehouse
              ? themeRed.withValues(alpha: 0.3)
              : Colors.grey.shade200,
          width: isCurrentWarehouse ? 2 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                // Warehouse Icon
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: isCurrentWarehouse
                        ? themeRed.withValues(alpha: 0.1)
                        : Colors.blue.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Center(
                    child: Text(
                      stock.warehouseId,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                        color: isCurrentWarehouse ? themeRed : Colors.blue,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),

                // Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            'Warehouse ${stock.warehouseId}',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          if (isCurrentWarehouse) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: themeRed,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Text(
                                'CURRENT',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      Text(
                        '${stock.locations.length} location${stock.locations.length != 1 ? 's' : ''}',
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),

                // Status Badge
                if (isLowStock)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: themeRed,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Text(
                      'LOW',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
              ],
            ),
          ),

          // Locations List
          if (stock.locations.isNotEmpty)
            Container(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
              child: Column(
                children: stock.locations.map((location) {
                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.location_on, size: 16, color: Colors.grey.shade600),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            location.bay.isNotEmpty ? location.bay : 'No bay assigned',
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                            ),
                          ),
                        ),
                        Text(
                          '${location.quantity} units',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: location.quantity < 10 ? themeRed : Colors.green.shade600,
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),

          // Stats
          Container(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            child: Row(
              children: [
                Expanded(
                  child: StatItem(
                    icon: Icons.inventory_2,
                    label: 'Total Quantity',
                    value: '${stock.totalQuantity} units',
                    color: isLowStock ? themeRed : Colors.green.shade600,
                  ),
                ),
                Expanded(
                  child: StatItem(
                    icon: Icons.attach_money,
                    label: 'Price',
                    value: 'RM ${stock.price.toStringAsFixed(2)}',
                    color: Colors.blue.shade600,
                  ),
                ),
              ],
            ),
          ),

          // Actions
          if (isCurrentWarehouse)
            Container(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: onRestock,
                      icon: const Icon(Icons.add_circle_outline),
                      label: const Text('Restock'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: themeRed,
                        side: BorderSide(color: themeRed),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: onEdit,
                      icon: const Icon(Icons.edit),
                      label: const Text('Edit'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.grey.shade700,
                        side: BorderSide(color: Colors.grey.shade300),
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class StatItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const StatItem({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 20, color: color),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade600,
              ),
            ),
            Text(
              value,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class SortOption extends StatelessWidget {
  final String title;
  final bool isSelected;
  final VoidCallback onTap;

  const SortOption({
    super.key,
    required this.title,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: Text(title),
      trailing: isSelected ? const Icon(Icons.check, color: Colors.blue) : null,
      onTap: onTap,
    );
  }
}

extension StringExtension on String {
  String capitalize() {
    return "${this[0].toUpperCase()}${substring(1)}";
  }
}