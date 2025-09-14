import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class IssueScanPage extends StatelessWidget {
  final Map<String, dynamic> request;
  const IssueScanPage({super.key, required this.request});

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

          return Column(
            children: [
              // 顶部信息卡（加入 Current Date）
              Container(
                margin: const EdgeInsets.fromLTRB(12, 12, 12, 8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFF90CAF9), width: 2),
                  boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 6, offset: Offset(0, 2))],
                ),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      RichText(
                        text: TextSpan(
                          style: const TextStyle(color: Colors.black87, fontSize: 14),
                          children: [
                            const TextSpan(text: 'Order ID : ', style: TextStyle(fontWeight: FontWeight.w600)),
                            TextSpan(text: requestId, style: const TextStyle(fontWeight: FontWeight.w900)),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(child: _kv('Request Date', _fmtDate(request['requestDate']))),
                          const SizedBox(width: 12),
                          Expanded(child: _kv('Expected Receive', _fmtDate(request['expectedReceiveDate']))),
                          const SizedBox(width: 12),
                          Expanded(child: _kv('Current Date', _fmtDate(DateTime.now()))),
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
                    const Text('Quantity', style: TextStyle(color: Colors.black54, fontWeight: FontWeight.w600)),
                  ],
                ),
              ),

              // 列表（带条码）
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

                    // 扫描完成：itemStatus == 'received' 或 qtyReceived >= qtyRequested
                    final status = (m['itemStatus'] ?? '').toString().toLowerCase();
                    final rec = (m['qtyReceived'] ?? 0) as num;
                    final reqq = (m['qtyRequested'] ?? 0) as num;
                    final scanned = status == 'received' || rec >= reqq;

                    final scanText = scanned ? 'Completed Scan' : 'No Complete Scan';
                    final scanColor = scanned ? const Color(0xFF2E7D32) : const Color(0xFFD32F2F);

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
                              // 图片占位
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
                                      scanned ? '• Stock Available' : '• Not Available',
                                      style: TextStyle(
                                        color: scanned ? const Color(0xFF2E7D32) : const Color(0xFFC62828),
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
                              Text(scanText, style: TextStyle(color: scanColor, fontWeight: FontWeight.w700)),
                              const Spacer(),
                              // 条码占位（可替换为条码组件）
                              Container(height: 18, width: 100, color: Colors.black12),
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),

              // 底部返回
              Container(
                color: Colors.white,
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Done', style: TextStyle(fontWeight: FontWeight.w700)),
                      ),
                    ),
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
}
