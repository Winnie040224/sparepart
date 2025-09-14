import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'addStockPage.dart';
import 'createNewItem.dart';
import 'search_page.dart';
import 'issuePage.dart';  // ← 新增这一行

/// KEEP SAME CLASS NAME
class HomePage extends StatefulWidget {
  const HomePage({super.key, this.currentWarehouseId = 'A'});
  final String currentWarehouseId;

  @override
  State<HomePage> createState() => _HomePageState();
}

/// Very small, focused home page:
/// - Normal AppBar (no bottom nav, no floating bar)
/// - Two primary big tiles (Part Request / Part Issue) -> placeholders
/// - Stats row (Products / Low Stock / Warehouses) using a single future
/// - Quick Action grid (Search / Add Stock / Create Item / Logout)
/// - Pull to refresh reloads stats
/// - All functions short & readable
class _HomePageState extends State<HomePage> {
  static const Color _brand = Color(0xFFE53935);

  // Dummy stats while you integrate real data.
  int _products = 0;
  int _lowStock = 0;
  int _warehouses = 0;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetchStats();
  }

  Future<void> _fetchStats() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      // TODO: Replace with your real service call when ready.
      // Example if you later add a service:
      // final stats = await FirebaseService().getStockStatistics();
      // setState(() {
      //   _products = stats['totalProducts'] ?? 0;
      //   _lowStock = stats['lowStockCount'] ?? 0;
      //   _warehouses = stats['warehouseCount'] ?? 0;
      //   _loading = false;
      // });

      await Future.delayed(const Duration(milliseconds: 350)); // simulate
      setState(() {
        _products = 18;
        _lowStock = 3;
        _warehouses = 2;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Failed to load stats';
        _loading = false;
      });
    }
  }

  // ------------- BUILD -------------
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F5F8),
      appBar: AppBar(
        backgroundColor: _brand,
        foregroundColor: Colors.white,
        title: const Text(
          'Staff Dashboard',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_outlined),
            tooltip: 'Notifications',
            onPressed: () => _toast('Notifications not implemented'),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _fetchStats,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _primaryRow(),
              const SizedBox(height: 24),
              _statsSection(),
              const SizedBox(height: 28),
              const _SectionLabel('Quick Actions'),
              const SizedBox(height: 12),
              _quickActionsGrid(),
            ],
          ),
        ),
      ),
    );
  }

  // ------------- SECTIONS -------------

  Widget _primaryRow() {
    return Row(
      children: [
        Expanded(
          child: _BigTile(
            label: 'Part Request',
            icon: Icons.touch_app_outlined,
            color: _brand,
            onTap: () => _toast('Part Request not implemented'),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _BigTile(
            label: 'Part Issue',
            icon: Icons.download_outlined,
            color: _brand,
            onTap:(){
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => IssuePage(
                    // 如果你的 IssuePage 构造函数是：IssuePage({ required this.currentWarehouseId })
                    currentWarehouseId: widget.currentWarehouseId,

                    // 如果你的 IssuePage 构造函数是：IssuePage({ required this.warehouseId })
                    // warehouseId: widget.currentWarehouseId,
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _statsSection() {
    if (_loading) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 24),
          child: CircularProgressIndicator(),
        ),
      );
    }
    if (_error != null) {
      return Center(
        child: Column(
          children: [
            Text(_error!, style: const TextStyle(color: Colors.red)),
            const SizedBox(height: 8),
            OutlinedButton(
              onPressed: _fetchStats,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionLabel('Overview'),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _StatChip(
                label: 'Products',
                value: _products.toString(),
                icon: Icons.widgets_outlined,
                color: Colors.blue.shade600,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _StatChip(
                label: 'Low Stock',
                value: _lowStock.toString(),
                icon: Icons.warning_amber_outlined,
                color: Colors.orange.shade700,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _StatChip(
                label: 'Warehouses',
                value: _warehouses.toString(),
                icon: Icons.warehouse_outlined,
                color: Colors.teal.shade600,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _quickActionsGrid() {
    final tiles = <_QuickActionData>[
      _QuickActionData(
        label: 'Search',
        icon: Icons.search,
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => SearchPage(currentWarehouseId: widget.currentWarehouseId),
            ),
          );
        },
      ),
      _QuickActionData(
        label: 'Add Stock',
        icon: Icons.add_box_outlined,
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => AddStockPage()),
        ),
      ),
      _QuickActionData(
        label: 'Create Item',
        icon: Icons.new_releases_outlined,
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => CreateNewItemPage()),
        ),
      ),
      _QuickActionData(
        label: 'Logout',
        icon: Icons.logout,
        color: Colors.red.shade600,
        onTap: () => _confirmLogout(),
      ),
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: tiles.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 18,
        crossAxisSpacing: 18,
        childAspectRatio: 1.05,
      ),
      itemBuilder: (_, i) => _QuickTile(data: tiles[i]),
    );
  }

  // ------------- HELPERS -------------

  void _toast(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), duration: const Duration(seconds: 1)),
    );
  }

  void _confirmLogout() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          FilledButton(
            onPressed: () {
              Navigator.pop(context);
              _toast('Logout not implemented');
            },
            child: const Text('Logout'),
          ),
        ],
      ),
    );
  }
}

//
// SMALL, REUSABLE WIDGETS (all very short)
//

class _BigTile extends StatelessWidget {
  const _BigTile({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      elevation: 2,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () {
          HapticFeedback.lightImpact();
          onTap();
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          child: Row(
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: color.withOpacity(.12),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(icon, size: 28, color: color),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _QuickActionData {
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final Color? color;
  _QuickActionData({
    required this.label,
    required this.icon,
    required this.onTap,
    this.color,
  });
}

class _QuickTile extends StatelessWidget {
  const _QuickTile({required this.data});
  final _QuickActionData data;

  @override
  Widget build(BuildContext context) {
    final c = data.color ?? const Color(0xFFE53935);
    return Material(
      color: Colors.white,
      elevation: 1,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {
          HapticFeedback.selectionClick();
          data.onTap();
        },
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 14, 12, 10),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 54,
                height: 54,
                decoration: BoxDecoration(
                  color: c.withOpacity(.12),
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Icon(data.icon, size: 30, color: c),
              ),
              const SizedBox(height: 10),
              Text(
                data.label,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  height: 1.15,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  const _StatChip({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 80,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: color.withOpacity(.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label.toUpperCase(),
                  style: TextStyle(
                    fontSize: 10.5,
                    letterSpacing: 0.7,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: color,
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

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);
  final String text;
  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 17,
        fontWeight: FontWeight.w700,
        color: Colors.black87,
        letterSpacing: .3,
      ),
    );
  }
}