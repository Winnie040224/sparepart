import 'package:flutter/material.dart';
import 'model.dart';

enum ProductCardLayout { full, minimal }

class ProductCard extends StatelessWidget {
  final Product product;
  final VoidCallback? onTap;
  final String? focusWarehouseId;
  final int lowStockThreshold;

  // Existing flags kept for backward compatibility, but layout overrides them
  final bool showStockInfo;
  final bool showRestockBadge;

  // NEW: choose full or minimal (minimal ignores other flags)
  final ProductCardLayout layout;

  const ProductCard({
    super.key,
    required this.product,
    this.onTap,
    this.focusWarehouseId,
    this.lowStockThreshold = 50,
    this.showStockInfo = true,
    this.showRestockBadge = true,
    this.layout = ProductCardLayout.full,
  });

  bool _isLowStock() {
    if (layout == ProductCardLayout.minimal) return false; // never show restock in minimal
    if (focusWarehouseId != null) {
      final stock = product.stockFor(focusWarehouseId!);
      if (stock != null) return stock.totalQuantity < lowStockThreshold;
    }
    return product.totalQty() < lowStockThreshold;
  }

  @override
  Widget build(BuildContext context) {
    final isMinimal = layout == ProductCardLayout.minimal;
    final low = _isLowStock();
    final themeRed = const Color(0xFFE53935);
    final focusStock = focusWarehouseId != null ? product.stockFor(focusWarehouseId!) : null;
    final displayStock = focusStock ?? (product.stocks.isNotEmpty ? product.stocks.first : null);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade300, width: 1),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.07),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        padding: isMinimal ? const EdgeInsets.all(8) : EdgeInsets.zero,
        child: isMinimal
            ? _buildMinimal()
            : _buildFull(themeRed, low, displayStock),
      ),
    );
  }

  // ---------------- Minimal Layout ----------------
  Widget _buildMinimal() {
    return Column(
      children: [
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: _buildImage(fallbackIconSize: 40),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          product.name,
          maxLines: 2,
          textAlign: TextAlign.center,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: Colors.blue,
            height: 1.15,
          ),
        ),
      ],
    );
  }

  // ---------------- Full Layout ----------------
  Widget _buildFull(Color themeRed, bool low, Stock? displayStock) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Image
        Expanded(
          flex: 3,
          child: Container(
            width: double.infinity,
            decoration: const BoxDecoration(
              color: Colors.grey,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
            ),
            child: ClipRRect(
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
              child: _buildImage(),
            ),
          ),
        ),

        // Content
        Expanded(
          flex: 4,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  product.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.blue,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'ID: ${product.docId}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey.shade600,
                  ),
                ),
                const SizedBox(height: 8),

                if (showStockInfo)
                  if (displayStock != null) ...[
                    SpecRow(label: 'Bay', value: displayStock.primaryBay),
                    SpecRow(label: 'Quantity', value: displayStock.totalQuantity.toString()),
                    SpecRow(label: 'Price', value: 'RM ${displayStock.price.toStringAsFixed(2)}'),
                  ] else ...[
                    const SpecRow(label: 'Bay', value: '-'),
                    const SpecRow(label: 'Quantity', value: '0'),
                    const SpecRow(label: 'Price', value: 'RM 0.00'),
                  ],

                const Spacer(),

                if (showRestockBadge && low)
                  Container(
                    height: 16,
                    decoration: BoxDecoration(
                      color: themeRed,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: const Center(
                      child: Text(
                        'Restock',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildImage({double fallbackIconSize = 48}) {
    if (product.imageName.isEmpty) {
      return Container(
        color: Colors.grey.shade200,
        child: Center(
          child: Icon(
            Icons.image,
            size: fallbackIconSize,
            color: Colors.grey,
          ),
        ),
      );
    }

    return Image.asset(
      product.imageAssetPath,
      fit: BoxFit.cover,
      errorBuilder: (context, error, stackTrace) {
        return Container(
          color: Colors.grey.shade200,
          child: Center(
            child: Icon(
              Icons.broken_image,
              size: fallbackIconSize,
              color: Colors.grey,
            ),
          ),
        );
      },
    );
  }
}

class SpecRow extends StatelessWidget {
  final String label;
  final String value;

  const SpecRow({super.key, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1),
      child: Row(
        children: [
          SizedBox(
            width: 50,
            child: Text(
              '$label:',
              style: TextStyle(
                fontSize: 10,
                color: Colors.grey.shade600,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}