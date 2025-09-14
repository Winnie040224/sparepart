import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'orderDetail.dart';
import 'services/issue_service.dart';

class IssuePage extends StatelessWidget {
  // 改这里：把字段从 warehouseId 改成 currentWarehouseId
  final String currentWarehouseId; // 接收方仓库
  const IssuePage({super.key, required this.currentWarehouseId});

  String _fmtDate(dynamic v) {
    if (v == null) return '-';
    try {
      if (v is Timestamp) return _fmtDate(v.toDate());
      if (v is DateTime) {
        final d = v.day.toString().padLeft(2, '0');
        final m = v.month.toString().padLeft(2, '0');
        return '$d-$m-${v.year}';
      }
    } catch (_) {}
    return v.toString();
  }

  (String, Color) _statusChip(dynamic status) {
    final s = (status ?? 'pending').toString().toLowerCase();
    if (s == 'completed') return ('Completed', const Color(0xFF2E7D32));
    if (s == 'on_delivery') return ('On Delivery', const Color(0xFFFF8F00));
    if (s == 'rejected') return ('Reject', const Color(0xFFD32F2F));
    return ('Pending', const Color(0xFFFF8F00));
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: const Color(0xFFF2F2F2),
        appBar: AppBar(
          backgroundColor: const Color(0xFFE53935),
          foregroundColor: Colors.white,
          elevation: 0,
          title: const Text('Part Issue'),
            bottom: const TabBar(
              labelColor: Colors.white,               // 选中：白色
              unselectedLabelColor: Colors.white70,   // 未选：白色 70%
              labelStyle: TextStyle(
                fontWeight: FontWeight.w800,
                letterSpacing: .3,
              ),
              unselectedLabelStyle: TextStyle(
                fontWeight: FontWeight.w600,
                letterSpacing: .3,
              ),
              indicator: UnderlineTabIndicator(       // 指示线：白色
                borderSide: BorderSide(width: 3, color: Colors.white),
              ),
              tabs: [
                Tab(text: 'ISSUE ORDERS'),
                Tab(text: 'HISTORY'),
              ],
            ),

        ),
        body: StreamBuilder<List<Map<String, dynamic>>>(
          // 改这里：用 currentWarehouseId
          stream: IssueService().watchRequests(currentWarehouseId),
          builder: (context, snap) {
            if (snap.hasError) return Center(child: Text('Error: ${snap.error}'));
            if (!snap.hasData) return const Center(child: CircularProgressIndicator());
            final all = snap.data!;
            // 前端分组
            final pending = all
                .where((m) => (m['status'] ?? 'pending').toString().toLowerCase() == 'pending')
                .toList();
            final history = all
                .where((m) => (m['status'] ?? '').toString().toLowerCase() != 'pending')
                .toList();

            Widget buildList(List<Map<String, dynamic>> list) {
              if (list.isEmpty) return const Center(child: Text('No data'));
              return ListView.builder(
                padding: const EdgeInsets.all(12),
                itemCount: list.length,
                itemBuilder: (c, i) {
                  final r = list[i];
                  final (label, color) = _statusChip(r['status']);
                  final itemsCount = (r['itemsCount'] ?? 0).toString();
                  final confirmDate = r['receiveDate'] ?? r['shippedAt'] ?? r['updatedAt'];

                  return Card(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    child: InkWell(
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => OrderDetailPage(request: r)),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        child: ListTile(
                          title: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  'Order ID : ${r['requestId'] ?? r['id']}',
                                  style: const TextStyle(fontWeight: FontWeight.w800),
                                ),
                              ),
                              Text('$itemsCount Items',
                                  style: const TextStyle(fontWeight: FontWeight.w700)),
                            ],
                          ),
                          subtitle: Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Request Date : ${_fmtDate(r['requestDate'])}'),
                                Text('Expected Receive : ${_fmtDate(r['expectedReceiveDate'])}'),
                                Text('Confirm Date : ${_fmtDate(confirmDate)}'),
                              ],
                            ),
                          ),
                          trailing: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(label, style: TextStyle(color: color, fontWeight: FontWeight.w800)),
                              const SizedBox(height: 6),
                              const Icon(Icons.chevron_right),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                },
              );
            }

            return TabBarView(
              children: [
                buildList(pending), // ISSUE ORDERS → 只显示 pending
                buildList(history), // HISTORY → 其他状态
              ],
            );
          },
        ),

        // 底部导航占位
        bottomNavigationBar: Container(
          height: 62,
          decoration: const BoxDecoration(color: Colors.white, boxShadow: [
            BoxShadow(color: Colors.black12, blurRadius: 6, offset: Offset(0, -1))
          ]),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: const [
              _Nav(icon: Icons.home, label: 'Home'),
              _Nav(icon: Icons.search, label: 'Search'),
              _Nav(icon: Icons.inventory_2, label: 'Inventory\nAdjustment'),
              _Nav(icon: Icons.person, label: 'Profile'),
            ],
          ),
        ),
      ),
    );
  }
}

class _Nav extends StatelessWidget {
  final IconData icon;
  final String label;
  const _Nav({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon, size: 22),
        const SizedBox(height: 2),
        Text(label, textAlign: TextAlign.center, style: const TextStyle(fontSize: 10), maxLines: 2),
      ],
    );
  }
}
