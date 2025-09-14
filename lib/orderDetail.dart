import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'barcode_scan_page.dart';

class OrderDetailPage extends StatefulWidget {
  final Map<String, dynamic> request;
  const OrderDetailPage({super.key, required this.request});

  @override
  State<OrderDetailPage> createState() => _OrderDetailPageState();
}

class _OrderDetailPageState extends State<OrderDetailPage> {
  bool _scanMode = false; // 仅 pending 时按 Continue 进入扫描模式

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

  String _normStatus(dynamic s) =>
      (s ?? 'pending').toString().trim().toLowerCase().replaceAll(' ', '_');

  // ---------- Stock helpers (stocks/{warehouseId}_{productId}) ----------
  final _db = FirebaseFirestore.instance;

  Future<int> _getStockQty({
    required String warehouseId,
    required String productId,
  }) async {
    final docId = '${warehouseId}_$productId';
    final snap = await _db.collection('stocks').doc(docId).get();
    if (!snap.exists) return 0;
    final m = snap.data() as Map<String, dynamic>? ?? {};
    // 你的结构是 locations: [ { quantity: 150, ... }, ... ]
    final List locs = (m['locations'] as List?) ?? const [];
    int sum = 0;
    for (final e in locs) {
      if (e is Map && e['quantity'] != null) {
        final q = (e['quantity'] as num).toInt();
        sum += q;
      }
    }
    // 兜底：有些文档可能直接有 quantity 字段
    if (sum == 0 && m['quantity'] != null) {
      sum = (m['quantity'] as num).toInt();
    }
    return sum;
  }

  Future<bool> _allStockAvailable({
    required String warehouseId,
    required List<QueryDocumentSnapshot<Map<String, dynamic>>> itemDocs,
  }) async {
    for (final d in itemDocs) {
      final m = d.data();
      final productId = (m['productId'] ?? m['id'] ?? '').toString();
      final need = (m['qtyRequested'] ?? 0) as num;
      final have = await _getStockQty(warehouseId: warehouseId, productId: productId);
      if (have < need) return false;
    }
    return itemDocs.isNotEmpty;
  }

  Future<bool> _anyNotAvailable({
    required String warehouseId,
    required List<QueryDocumentSnapshot<Map<String, dynamic>>> itemDocs,
  }) async {
    for (final d in itemDocs) {
      final m = d.data();
      final productId = (m['productId'] ?? m['id'] ?? '').toString();
      final need = (m['qtyRequested'] ?? 0) as num;
      final have = await _getStockQty(warehouseId: warehouseId, productId: productId);
      if (have < need) return true;
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final requestId = (widget.request['requestId'] ?? widget.request['id']).toString();
    final requestDocRef = _db.collection('requests').doc(requestId);

    return Scaffold(
      backgroundColor: const Color(0xFFF2F2F2),
      appBar: AppBar(
        backgroundColor: const Color(0xFFE53935),
        foregroundColor: Colors.white,
        title: Text(requestId),
        elevation: 0,
      ),

      // 先监听父文档，实时拿 status/fromWarehouseId
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: requestDocRef.snapshots(),
        builder: (context, reqSnap) {
          final reqData = reqSnap.data?.data() ?? widget.request;
          final status = _normStatus(reqData['status']);
          final isCompleted = status == 'completed';
          final statusColor = isCompleted
              ? const Color(0xFF2E7D32)
              : (status == 'rejected'
              ? const Color(0xFFD32F2F)
              : const Color(0xFFFF8F00));
          final fromWh = (reqData['toWarehouseId'] ?? '').toString(); // ← 发货仓

          // 只有 pending 才允许扫描模式；如果状态已不是 pending，强制退出扫描模式
          if (status != 'pending' && _scanMode) {
            _scanMode = false;
          }

          return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: requestDocRef.collection('items').snapshots(),
            builder: (context, snap) {
              final loading = !snap.hasData && !snap.hasError;
              final docs = snap.data?.docs ?? [];

              return Column(
                children: [
                  // 顶部信息卡
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
                                _titleCase(status.replaceAll('_', ' ')),
                                style: TextStyle(color: statusColor, fontWeight: FontWeight.w900),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(child: _kv('Request Date', _fmtDate(reqData['requestDate']))),
                              const SizedBox(width: 12),
                              Expanded(child: _kv('Expected Receive', _fmtDate(reqData['expectedReceiveDate']))),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),

                  // 小节标题
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 12),
                    padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
                      boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 6, offset: Offset(0, 2))],
                    ),
                    child: Row(
                      children: const [
                        Expanded(
                          child: Text('Receiving Items ( )', // 数量在列表上面看不到就不强求
                              style: TextStyle(fontWeight: FontWeight.w800)),
                        ),
                        Text('Quantity',
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
                        final ref = docs[i].reference;
                        final m = docs[i].data();

                        final title = (m['productName'] ?? '').toString();
                        final subtitle = _catLabel(m['categoryId']?.toString());
                        final qtyNeed = (m['qtyRequested'] ?? 0) as num;
                        final scanCompleted = (m['scanCompleted'] ?? false) == true;
                        final expectedBarcode = (m['productId'] ?? m['id'] ?? '').toString();
                        final productId = expectedBarcode;

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
                                    child: Container(
                                      width: 56,
                                      height: 56,
                                      color: const Color(0xFFF0F0F0),
                                      child: const Icon(Icons.image, color: Colors.black45),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          title.isEmpty ? 'Unnamed Item' : title,
                                          style: const TextStyle(
                                            color: Color(0xFF1976D2),
                                            fontWeight: FontWeight.w800,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(subtitle, style: const TextStyle(color: Colors.black54)),
                                        const SizedBox(height: 6),

                                        // ← 实时显示该发货仓的库存数量，并判定是否可发
                                        FutureBuilder<int>(
                                          future: _getStockQty(
                                            warehouseId: fromWh,
                                            productId: productId,
                                          ),
                                          builder: (context, stockSnap) {
                                            final have = stockSnap.data ?? 0;
                                            final available = have >= qtyNeed;
                                            return Text(
                                              available
                                                  ? '• Stock Available  ( $have )'
                                                  : '• Not Available  ( $have )',
                                              style: TextStyle(
                                                color: available
                                                    ? const Color(0xFF2E7D32)
                                                    : const Color(0xFFC62828),
                                                fontWeight: FontWeight.w600,
                                              ),
                                            );
                                          },
                                        ),
                                      ],
                                    ),
                                  ),
                                  Text(
                                    '$qtyNeed',
                                    style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              Row(
                                children: [
                                  // ✅ 只有 pending 且 _scanMode 才显示扫描状态文字
                                  if (status == 'pending' && _scanMode)
                                    Text(
                                      scanCompleted ? 'Completed Scan' : 'No Complete Scan',
                                      style: TextStyle(
                                        color: scanCompleted
                                            ? const Color(0xFF2E7D32)
                                            : const Color(0xFFD32F2F),
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  const Spacer(),
                                  // ✅ 只有 pending + _scanMode + 未完成扫描 才显示 Scan 按钮
                                  if (status == 'pending' && _scanMode && !scanCompleted)
                                    SizedBox(
                                      height: 32,
                                      child: OutlinedButton.icon(
                                        icon: const Icon(Icons.qr_code_scanner, size: 18),
                                        label: const Text('Scan'),
                                        onPressed: () async {
                                          final code = await Navigator.push<String?>(
                                            context,
                                            MaterialPageRoute(
                                              builder: (_) => const BarcodeScanPage(),
                                            ),
                                          );
                                          if (code == null) return;

                                          if (code.trim() == expectedBarcode.trim()) {
                                            await ref.update({
                                              'scanCompleted': true,
                                              'updatedAt': FieldValue.serverTimestamp(),
                                            });
                                            if (mounted) {
                                              ScaffoldMessenger.of(context).showSnackBar(
                                                const SnackBar(
                                                    content: Text('Scan matched. Marked completed.')),
                                              );
                                            }
                                          } else {
                                            if (mounted) {
                                              ScaffoldMessenger.of(context).showSnackBar(
                                                SnackBar(
                                                  content: Text(
                                                      'Barcode not match (expected $expectedBarcode).'),
                                                ),
                                              );
                                            }
                                          }
                                        },
                                      ),
                                    )
                                  else
                                    const SizedBox(height: 18, width: 100),
                                ],
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),

                  // ✅ 仅在 pending 且“存在任一缺货”时显示提示行（用 stocks 判断）
                  if (status == 'pending')
                    FutureBuilder<bool>(
                      future: _anyNotAvailable(warehouseId: fromWh, itemDocs: docs),
                      builder: (context, f) {
                        if (f.data != true) return const SizedBox.shrink();
                        return Padding(
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              '* Not Available – Please restock before issuing, else reject it.',
                              style: TextStyle(color: Colors.black.withOpacity(0.55), fontSize: 12),
                            ),
                          ),
                        );
                      },
                    ),

                  // ====== 底部按钮区（只在 pending 展示） ======
                  if (status == 'pending')
                    Container(
                      color: Colors.white,
                      padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
                      child: Row(
                        children: [
                          // Reject
                          Expanded(
                            child: OutlinedButton(
                              style: OutlinedButton.styleFrom(
                                foregroundColor: const Color(0xFFE53935),
                                side: const BorderSide(color: Color(0xFFE53935), width: 1.5),
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                              onPressed: () async {
                                final ok = await _confirmDialog(
                                  context,
                                  title: 'Reject',
                                  color: const Color(0xFFE53935),
                                  message: 'Are you sure you want to reject this request?',
                                  confirmText: 'Reject',
                                  icon: Icons.cancel,
                                );
                                if (ok == true) {
                                  await requestDocRef.update({
                                    'status': 'rejected',
                                    'updatedAt': FieldValue.serverTimestamp(),
                                  });
                                  if (mounted) Navigator.pop(context);
                                }
                              },
                              child: const Text('Reject', style: TextStyle(fontWeight: FontWeight.w700)),
                            ),
                          ),
                          const SizedBox(width: 10),

                          // Cancel
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

                          // Continue
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
                              onPressed: () async {
                                if (!_scanMode) {
                                  // 第一次点：先检查“全部可发货” → 进入扫描模式
                                  final ok = await _allStockAvailable(
                                    warehouseId: fromWh,
                                    itemDocs: docs,
                                  );
                                  if (!ok) {
                                    if (!mounted) return;
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(content: Text('Some items are not available in stock.')),
                                    );
                                    return;
                                  }
                                  setState(() => _scanMode = true);
                                  return;
                                }

                                // 扫描模式：必须全部 scanCompleted 才能继续
                                final allScanned = docs.isNotEmpty &&
                                    docs.every((d) => (d.data()['scanCompleted'] ?? false) == true);
                                if (!allScanned) {
                                  if (!mounted) return;
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('Please complete all scans first.')),
                                  );
                                  return;
                                }

                                final ok2 = await _confirmDialog(
                                  context,
                                  title: 'Confirm',
                                  color: const Color(0xFF66BB6A),
                                  message: 'Are you sure you want to confirm the request?',
                                  confirmText: 'Confirm',
                                  icon: Icons.check_circle,
                                );
                                if (ok2 == true) {
                                  await requestDocRef.update({
                                    'status': 'on_delivery',
                                    'updatedAt': FieldValue.serverTimestamp(),
                                  });
                                  if (mounted) Navigator.pop(context);
                                } else {
                                  if (mounted) Navigator.pop(context); // 保持 pending
                                }
                              },
                              child: Text(_scanMode ? 'Continue' : 'Continue',
                                  style: const TextStyle(fontWeight: FontWeight.w700)),
                            ),
                          ),
                        ],
                      ),
                    ),

                  // 底部导航占位
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
          );
        },
      ),
    );
  }

  Future<bool?> _confirmDialog(
      BuildContext context, {
        required String title,
        required Color color,
        required String message,
        required String confirmText,
        required IconData icon,
      }) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
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
                  Text(
                    message,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 6, 12, 12),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context, false),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(context, true),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: color,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: Text(confirmText),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _titleCase(String s) =>
      s.split(' ').map((w) => w.isEmpty ? w : (w[0].toUpperCase() + w.substring(1))).join(' ');

  Widget _kv(String k, String v) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(k, style: const TextStyle(color: Colors.black54, fontSize: 12)),
      const SizedBox(height: 4),
      Text(v, style: const TextStyle(fontWeight: FontWeight.w700)),
    ],
  );
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
