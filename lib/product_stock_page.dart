import 'package:flutter/material.dart';
import 'model.dart';
import 'services/firebase_service.dart';

class ProductStockPage extends StatelessWidget {
  final Product product;
  final String currentWarehouseId; // e.g. "A"
  ProductStockPage({super.key, required this.product, required this.currentWarehouseId});

  final _svc = FirebaseService();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Availability')),
      body: Column(
        children: [
          // 顶部产品信息
          Container(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Image.asset(product.assetPath, width: 90, height: 90, fit: BoxFit.contain),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(product.name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                      const SizedBox(height: 6),
                      Text('ID : ${product.id}', style: const TextStyle(color: Colors.black54)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),

          // 按仓库分组的库存
          Expanded(
            child: StreamBuilder<Map<Warehouse, List<StockEntry>>>(
              stream: _svc.watchProductStocksAcrossWarehouses(product),
              builder: (context, snap) {
                if (!snap.hasData) return const Center(child: CircularProgressIndicator());
                final grouped = snap.data!;
                if (grouped.isEmpty) return const Center(child: Text('No stock'));

                return ListView(
                  padding: const EdgeInsets.all(12),
                  children: grouped.entries.map((e) {
                    final wh = e.key;
                    final rows = e.value;
                    final canRestock = wh.id == currentWarehouseId || wh.code == currentWarehouseId;
                    return _WarehouseSection(
                      warehouse: wh,
                      rows: rows,
                      canRestock: canRestock,
                    );
                  }).toList(),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _WarehouseSection extends StatelessWidget {
  final Warehouse warehouse;
  final List<StockEntry> rows;
  final bool canRestock;

  const _WarehouseSection({
    required this.warehouse,
    required this.rows,
    required this.canRestock,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('${warehouse.name} :', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
        const SizedBox(height: 8),
        ...rows.map((r) => _InventoryCard(row: r, canRestock: canRestock)),
        const SizedBox(height: 12),
      ],
    );
  }
}

class _InventoryCard extends StatelessWidget {
  final StockEntry row;
  final bool canRestock;

  const _InventoryCard({required this.row, required this.canRestock});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: Colors.black12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            _kv('Bay', row.bay),
            _kv('Quantity', '${row.quantity}'),
            _kv('Price', 'RM ${row.price.toStringAsFixed(2)}'),
            const SizedBox(height: 8),
            if (canRestock)
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    // TODO: 在这里接你的补货流程（弹窗/跳转）
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Restock clicked')),
                    );
                  },
                  icon: const Icon(Icons.inventory_2),
                  label: const Text('Restock'),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _kv(String k, String v) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          SizedBox(width: 90, child: Text('$k :')),
          Expanded(
            child: Text(
              v,
              style: const TextStyle(fontWeight: FontWeight.w700, color: Colors.blue),
            ),
          ),
        ],
      ),
    );
  }
}
