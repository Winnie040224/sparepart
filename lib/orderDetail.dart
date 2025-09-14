import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'issue_scan_page.dart';

class OrderDetailPage extends StatelessWidget {
  final Map<String, dynamic> request;
  const OrderDetailPage({super.key, required this.request});

  // ===== helpers =====
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

  String _catLabel(String? id) {
    switch ((id ?? '').toString()) {
      case 'engine_components':
        return 'Engine Components';
      case 'body_exterior':
        return 'Body & Exterior';
      default:
        return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final requestId = (request['requestId'] ?? request['id']).toString();

    // 状态
    final status = (request['status'] ?? 'pending').toString().toLowerCase();
    final isPending = status == 'pending';
    final isCompleted = status == 'completed';
    final statusColor = isCompleted
        ? const Color(0xFF2E7D32)
        : (status == 'rejected'
        ? const Color(0xFFD32F2F)
        : const Color(0xFFFF8F00));

    // 子集合 items
    final itemsStream = FirebaseFirestore.instance
        .collection('requests')
        .doc(requestId)
        .collection('items')
        .snapshots();

    return Scaffold(
      backgroundColor: const Color(0xFFF2F2F2),
      appBar: AppBar(
        backgroundColor: const Color(0xFFE53935),
        foregroundColor: Colors.white,
        title: Text(requestId),
        elevation: 0,
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: itemsStream,
        builder: (context, snap) {
          final loading = !snap.hasData && !snap.hasError;
          final docs = snap.data?.docs ?? [];

          // 全部可用：qtyReceived >= qtyRequested
          final allAvailable = docs.isNotEmpty &&
              docs.every((d) {
                final m = d.data();
                final rec = (m['qtyReceived'] ?? 0) as num;
                final reqq = (m['qtyRequested'] ?? 0) as num;
                return rec >= reqq;
              });

          return Column(
            children: [
              // 顶部蓝边信息卡
              Container(
                margin: const EdgeInsets.fromLTRB(12, 12, 12, 8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFF90CAF9), width: 2),
                  boxShadow: const [
                    BoxShadow(color: Colors.black12, blurRadius: 6, offset: Offset(0, 2))
                  ],
                ),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: RichText(
                              text: TextSpan(
                                style: const TextStyle(color: Colors.black87, fontSize: 14),
                                children: [
                                  const TextSpan(
                                    text: 'Order ID : ',
                                    style: TextStyle(fontWeight: FontWeight.w600),
                                  ),
                                  TextSpan(
                                    text: requestId,
                                    style: const TextStyle(fontWeight: FontWeight.w900),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          Text(
                            status[0].toUpperCase() + status.substring(1),
                            style: TextStyle(color: statusColor, fontWeight: FontWeight.w900),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(child: _kv('Request Date', _fmtDate(request['requestDate']))),
                          const SizedBox(width: 12),
                          Expanded(child: _kv('Expected Receive', _fmtDate(request['expectedReceiveDate']))),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              // Receiving Items (n)
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 12),
                padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                  boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 6, offset: Offset(0, 2))],
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text('Receiving Items (${docs.length})',
                          style: const TextStyle(fontWeight: FontWeight.w800)),
                    ),
                    const Text('Quantity',
                        style: TextStyle(color: Colors.black54, fontWeight: FontWeight.w600)),
                  ],
                ),
              ),

              // 列表
              Expanded(
                child: loading
                    ? const Center(child: CircularProgressIndicator())
                    : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 0),
                  itemCount: docs.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, i) {
                    final m = docs[i].data();
                    final title = (m['productName'] ?? '').toString();
                    final subtitle = _catLabel(m['categoryId']?.toString());
                    final qty = (m['qtyRequested'] ?? 0).toString();
                    final rec = (m['qtyReceived'] ?? 0) as num;
                    final reqq = (m['qtyRequested'] ?? 0) as num;
                    final available = rec >= reqq;

                    final scanText = available ? 'Completed Scan' : 'No Complete Scan';
                    final scanColor = available ? const Color(0xFF2E7D32) : const Color(0xFFD32F2F);

                    return Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: const [
                          BoxShadow(color: Colors.black12, blurRadius: 6, offset: Offset(0, 2))
                        ],
                      ),
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(10),
                                child: SizedBox(
                                  width: 56,
                                  height: 56,
                                  child: Container(
                                    color: const Color(0xFFF0F0F0),
                                    child: const Icon(Icons.image, color: Colors.black45),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(title.isEmpty ? 'Unnamed Item' : title,
                                        style: const TextStyle(
                                          color: Color(0xFF1976D2),
                                          fontWeight: FontWeight.w800,
                                        )),
                                    const SizedBox(height: 4),
                                    Text(subtitle, style: const TextStyle(color: Colors.black54)),
                                    const SizedBox(height: 6),
                                    Text(
                                      available ? '• Stock Available' : '• Not Available',
                                      style: TextStyle(
                                        color: available ? const Color(0xFF2E7D32) : const Color(0xFFC62828),
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Text(qty, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              Text(scanText,
                                  style: TextStyle(color: scanColor, fontWeight: FontWeight.w700)),
                              const Spacer(),
                              Container(height: 18, width: 100, color: Colors.black12), // 条码占位
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),

              // 仅在「pending 且 not allAvailable」时出现的提示
              if (isPending && !allAvailable)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      '* Not Available – Please restock before issuing, else reject it.',
                      style: TextStyle(color: Colors.black.withOpacity(0.55), fontSize: 12),
                    ),
                  ),
                ),

              // 按钮区：只有 pending 时才显示；Continue 需 allAvailable 才能点击
              if (isPending)
                Container(
                  color: Colors.white,
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
                  child: Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFFE53935),
                            side: const BorderSide(color: Color(0xFFE53935), width: 1.5),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          onPressed: () => _showDialog(
                            context,
                            title: 'Reject',
                            color: const Color(0xFFE53935),
                            message: 'Are you sure you want to reject this request?',
                            confirmText: 'Reject',
                            icon: Icons.cancel,
                          ),
                          child: const Text('Reject', style: TextStyle(fontWeight: FontWeight.w700)),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          onPressed: () => Navigator.pop(context),
                          child: const Text('Cancel', style: TextStyle(fontWeight: FontWeight.w700)),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF66BB6A),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            disabledBackgroundColor: Colors.grey.shade400,
                            disabledForegroundColor: Colors.white,
                          ),
                          onPressed: allAvailable
                              ? () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => IssueScanPage(request: request),
                              ),
                            );
                          }
                              : null,
                          child: const Text('Continue', style: TextStyle(fontWeight: FontWeight.w700)),
                        ),
                      ),
                    ],
                  ),
                ),

              // 底部导航占位（与设计图一致）
              Container(
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
            ],
          );
        },
      ),
    );
  }

  Widget _kv(String k, String v) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(k, style: const TextStyle(color: Colors.black54, fontSize: 12)),
      const SizedBox(height: 4),
      Text(v, style: const TextStyle(fontWeight: FontWeight.w700)),
    ],
  );

  Future<void> _showDialog(
      BuildContext context, {
        required String title,
        required Color color,
        required String message,
        required String confirmText,
        required IconData icon,
      }) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => Dialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 40),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: color,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
              ),
              child: Center(
                child: Text(title,
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 18, 16, 8),
              child: Column(
                children: [
                  Icon(icon, size: 40, color: color),
                  const SizedBox(height: 10),
                  Text(message,
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                ],
              ),
            ),
            const Divider(height: 1),
            Row(
              children: [
                Expanded(child: TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel'))),
                Expanded(child: TextButton(onPressed: () => Navigator.pop(context, true), child: Text(confirmText, style: TextStyle(color: color)))),
              ],
            ),
          ],
        ),
      ),
    );

    if (ok == true && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$title success')));
    }
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
