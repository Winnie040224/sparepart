// lib/pending_page.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'main.dart';
import 'services/request_service.dart';
import 'request_detail_page.dart';

class PendingPage extends StatelessWidget {
  const PendingPage({super.key});

  @override
  Widget build(BuildContext context) {
    final df = DateFormat('dd-MM-yyyy');

    // 订阅 warehouses，做一个 {id -> name} 的字典
    final whStream = FirebaseFirestore.instance
        .collection('warehouses')
        .orderBy(FieldPath.documentId)
        .snapshots();

    // 订阅 pending 列表
    final reqStream = RequestService.instance.myPendingNoIndex(kFromWarehouseId);

    return Container(
      color: const Color(0xFFF7F7FA),
      child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: whStream,
        builder: (context, whSnap) {
          final Map<String, String> whNameMap = {
            for (final d in (whSnap.data?.docs ?? const []))
              d.id: (d.data()['name'] as String?) ?? d.id,
          };

          return StreamBuilder<List<Map<String, dynamic>>>(
            stream: reqStream,
            builder: (context, snap) {
              if (snap.hasError) {
                return Center(child: Text('Error: ${snap.error}'));
              }
              if (!snap.hasData) {
                return const Center(child: CircularProgressIndicator());
              }

              final list = snap.data!;
              if (list.isEmpty) {
                return const _EmptyState();
              }

              return ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
                itemCount: list.length,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (context, i) {
                  final m = list[i];

                  final docId = (m['__id'] as String?) ?? '';
                  final requestId = (m['requestId'] as String?) ?? docId;

                  final status = (m['status'] as String?) ?? 'pending';
                  final toWhId = (m['toWarehouseId'] as String?) ?? '-';
                  final itemsCount = (m['itemsCount'] as num?)?.toInt() ?? 0;

                  String _fmtDate(dynamic v) {
                    DateTime? dt;
                    if (v is Timestamp) dt = v.toDate();
                    if (v is DateTime) dt = v;
                    return dt != null ? df.format(dt) : '-';
                  }

                  final reqDate = _fmtDate(m['requestDate']);
                  final expDate = _fmtDate(m['expectedReceiveDate']);

                  // 只显示仓库“名字”，不显示 (ID)
                  final toWhName = whNameMap[toWhId] ?? toWhId;

                  return _RequestCard(
                    requestId: requestId,
                    toWarehouseName: toWhName,
                    itemsCount: itemsCount,
                    requestDateText: reqDate,
                    expectedDateText: expDate,
                    status: status,
                    onTap: docId.isEmpty
                        ? null
                        : () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => RequestDetailPage(requestId: docId),
                      ),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}

/* --------------------------- 美观的卡片 --------------------------- */

class _RequestCard extends StatelessWidget {
  const _RequestCard({
    required this.requestId,
    required this.toWarehouseName,
    required this.itemsCount,
    required this.requestDateText,
    required this.expectedDateText,
    required this.status,
    this.onTap,
  });

  final String requestId;
  final String toWarehouseName; // 只显示名称
  final int itemsCount;
  final String requestDateText;
  final String expectedDateText;
  final String status;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final styles = _StatusStyle.of(status);

    return Material(
      color: Colors.white,
      elevation: 0,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        splashColor: styles.color.withOpacity(.08),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            boxShadow: const [
              BoxShadow(color: Color(0x12000000), blurRadius: 10, offset: Offset(0, 4)),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 左侧信息
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 顶部：订单号 + Items 徽章
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              'Order ID : $requestId',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF101316),
                              ),
                            ),
                          ),
                          _ItemsBadge(count: itemsCount),
                        ],
                      ),
                      const SizedBox(height: 10),

                      // 日期（两行）
                      _InfoRow(
                        icon: Icons.event_rounded,
                        text: 'Request Date : $requestDateText',
                      ),
                      const SizedBox(height: 4),
                      _InfoRow(
                        icon: Icons.schedule_rounded,
                        text: 'Expected Receive : $expectedDateText',
                      ),
                      const SizedBox(height: 8),

                      // ★ Requester To：放在 Expected Receive 下面，并用蓝色胶囊强调
                      _RequesterToChip(name: toWarehouseName),
                    ],
                  ),
                ),

                const SizedBox(width: 10),

                // 右侧：状态胶囊 + 箭头
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    _StatusChip(label: styles.label, color: styles.color),
                    const SizedBox(height: 22),
                    const Icon(Icons.chevron_right_rounded, size: 22, color: Colors.black54),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/* --------------------------- 小组件 --------------------------- */

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 16, color: const Color(0xFF9097A3)),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(fontSize: 13, color: Color(0xFF32373D), height: 1.2),
          ),
        ),
      ],
    );
  }
}

class _ItemsBadge extends StatelessWidget {
  const _ItemsBadge({required this.count});
  final int count;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFEFF3F8),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        '$count Items',
        style: const TextStyle(
          fontWeight: FontWeight.w700,
          fontSize: 12,
          color: Color(0xFF3C4450),
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.label, required this.color});
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(.1),
        border: Border.all(color: color.withOpacity(.4)),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontWeight: FontWeight.w900,
          fontSize: 14,
          color: color,
          height: 1,
          letterSpacing: .2,
        ),
      ),
    );
  }
}

// 「Requester To」的蓝色胶囊（带图标，更醒目）
class _RequesterToChip extends StatelessWidget {
  const _RequesterToChip({required this.name});
  final String name;

  @override
  Widget build(BuildContext context) {
    const Color chipColor = Color(0xFF1976D2);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: chipColor.withOpacity(.10),
        border: Border.all(color: chipColor.withOpacity(.35)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: const [
          Icon(Icons.store_mall_directory_rounded, size: 16, color: chipColor),
          SizedBox(width: 6),
          // 文本在外层再加个 Expanded 会撑满，这里只做 tag 样式
        ],
      ),
    ).withText('Requester To : $name');
  }
}

// 给任意 Container 追加一段文本的便捷扩展（为了写法简洁）
extension _WithText on Widget {
  Widget withText(String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        this,
        const SizedBox(width: 6),
        Text(
          text,
          style: const TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 13,
            color: Color(0xFF0F3D75),
          ),
        ),
      ],
    );
  }
}

/* --------------------------- 状态样式映射 --------------------------- */

class _StatusStyle {
  final String label;
  final Color color;
  const _StatusStyle(this.label, this.color);

  static _StatusStyle of(String status) {
    switch (status) {
      case 'pending':
        return const _StatusStyle('Pending', Color(0xFF1976D2)); // 蓝
      case 'on_delivery':
        return const _StatusStyle('On Delivery', Color(0xFFFF8C00)); // 橙
      case 'completed':
        return const _StatusStyle('Completed', Color(0xFF2E7D32)); // 绿
      case 'rejected':
        return const _StatusStyle('Rejected', Color(0xFFD32F2F)); // 红
      default:
        return _StatusStyle(status, const Color(0xFF616161));
    }
  }
}

/* --------------------------- 空状态 --------------------------- */

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: const [
            Icon(Icons.inbox_rounded, size: 48, color: Color(0xFFB0B6BF)),
            SizedBox(height: 12),
            Text(
              'No pending requests',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Color(0xFF6A7280)),
            ),
            SizedBox(height: 6),
            Text(
              'Requests you create will show up here.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: Color(0xFF8A93A3)),
            ),
          ],
        ),
      ),
    );
  }
}
