// lib/services/request_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';

class RequestService {
  RequestService._();
  static final instance = RequestService._();

  final _db = FirebaseFirestore.instance;

  // ====================== 辅助：解析 REQ-000123 -> 123 ======================
  int? _parseNumberFromId(String s) {
    final m = RegExp(r'^REQ-(\d+)$').firstMatch(s);
    if (m == null) return null;
    return int.tryParse(m.group(1)!);
  }

  // ====================== 生成下一个最小可用编号（扫描法） ======================
  //
  // 说明：读取现有 requests，把形如 REQ-xxxxxx 的数字收集到集合，
  // 从 1 起找最小缺失，格式化成 REQ-000001 返回。
  // 注意：高并发下可能撞号，适合低并发/单人使用场景。
  Future<String> nextRequestIdByScanning() async {
    final qs = await _db.collection('requests').get();

    final existing = <int>{};
    for (final d in qs.docs) {
      final raw = (d.data()['requestId'] as String?) ?? d.id;
      final n = _parseNumberFromId(raw);
      if (n != null && n > 0) existing.add(n);
    }

    int candidate = 1;
    while (existing.contains(candidate)) {
      candidate++;
    }
    return 'REQ-${candidate.toString().padLeft(6, '0')}';
  }

  // ====================== 创建请求（外部指定 requestId） ======================
  // items 字段至少包含：
  //   productId, productName, imageName, categoryId, qtyRequested(int)
  Future<void> createRequest({
    required String requestId,
    required String fromWarehouseId,
    required String toWarehouseId,
    required String createdByUserId,
    required DateTime requestDate,
    required List<Map<String, dynamic>> items,
    int expectedDays = 7,                 // 默认 +7 天
    DateTime? expectedReceiveDateOverride // 显式指定预计日期（优先）
  }) async {
    final headerRef = _db.collection('requests').doc(requestId);
    final itemsRef = headerRef.collection('items');
    final batch = _db.batch();

    // 预计到货：优先 override，否则按 requestDate(去时分秒) + expectedDays
    final baseDay = DateTime(requestDate.year, requestDate.month, requestDate.day);
    final expDate = expectedReceiveDateOverride ?? baseDay.add(Duration(days: expectedDays));

    batch.set(headerRef, {
      'requestId': requestId,
      'fromWarehouseId': fromWarehouseId,
      'toWarehouseId': toWarehouseId,
      'status': 'pending', // pending -> on_delivery -> completed/rejected
      'itemsCount': items.length,
      'requestDate': Timestamp.fromDate(baseDay),
      'expectedReceiveDate': Timestamp.fromDate(expDate),
      'shippedAt': null,
      'receiveDate': null,
      'rejectReason': null,
      'createdByUserId': createdByUserId,
      'updatedAt': FieldValue.serverTimestamp(),
    });

    for (final it in items) {
      batch.set(itemsRef.doc(), it);
    }

    await batch.commit();
  }

  // ====================== 直接创建并自动分配（扫描法） ======================
  Future<String> createRequestAutoIdByScanning({
    required String fromWarehouseId,
    required String toWarehouseId,
    required String createdByUserId,
    required DateTime requestDate,
    required List<Map<String, dynamic>> items,
    int expectedDays = 7,
    DateTime? expectedReceiveDateOverride,
  }) async {
    final id = await nextRequestIdByScanning();
    await createRequest(
      requestId: id,
      fromWarehouseId: fromWarehouseId,
      toWarehouseId: toWarehouseId,
      createdByUserId: createdByUserId,
      requestDate: requestDate,
      items: items,
      expectedDays: expectedDays,
      expectedReceiveDateOverride: expectedReceiveDateOverride,
    );
    return id;
  }

  // ====================== 列表（Indexed / NoIndex） ======================

  // 需要在控制台创建复合索引
  Stream<QuerySnapshot<Map<String, dynamic>>> myPendingIndexed(String fromWarehouseId) {
    return _db
        .collection('requests')
        .where('fromWarehouseId', isEqualTo: fromWarehouseId)
        .where('status', whereIn: ['pending', 'on_delivery'])
        .orderBy('updatedAt', descending: true)
        .snapshots();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> myHistoryIndexed(String fromWarehouseId) {
    return _db
        .collection('requests')
        .where('fromWarehouseId', isEqualTo: fromWarehouseId)
        .where('status', whereIn: ['completed', 'rejected'])
        .orderBy('updatedAt', descending: true)
        .snapshots();
  }

  // 无索引：一次性拉取该仓库的所有请求，客户端过滤 + 排序
  Stream<List<Map<String, dynamic>>> myPendingNoIndex(String fromWarehouseId) {
    return _db
        .collection('requests')
        .where('fromWarehouseId', isEqualTo: fromWarehouseId)
        .snapshots()
        .map((qs) {
      final list = qs.docs.map(_withId).where((m) {
        final s = (m['status'] as String?) ?? '';
        return s == 'pending' || s == 'on_delivery';
      }).toList();

      list.sort((a, b) {
        final ta = (a['updatedAt'] as Timestamp?)?.toDate() ??
            DateTime.fromMillisecondsSinceEpoch(0);
        final tb = (b['updatedAt'] as Timestamp?)?.toDate() ??
            DateTime.fromMillisecondsSinceEpoch(0);
        return tb.compareTo(ta); // desc
      });
      return list;
    });
  }

  Stream<List<Map<String, dynamic>>> myHistoryNoIndex(String fromWarehouseId) {
    return _db
        .collection('requests')
        .where('fromWarehouseId', isEqualTo: fromWarehouseId)
        .snapshots()
        .map((qs) {
      final list = qs.docs.map(_withId).where((m) {
        final s = (m['status'] as String?) ?? '';
        return s == 'completed' || s == 'rejected';
      }).toList();

      list.sort((a, b) {
        final ta = (a['updatedAt'] as Timestamp?)?.toDate() ??
            DateTime.fromMillisecondsSinceEpoch(0);
        final tb = (b['updatedAt'] as Timestamp?)?.toDate() ??
            DateTime.fromMillisecondsSinceEpoch(0);
        return tb.compareTo(ta); // desc
      });
      return list;
    });
  }

  // ====================== B 仓：发货 / 拒绝 ======================

  /// 发货：
  /// - status -> on_delivery
  /// - shippedAt -> serverTimestamp
  /// - expectedReceiveDate：传入则覆盖；否则保持或按 requestDate+7 填充
  Future<void> shipRequest(
      String requestId, {
        DateTime? expectedReceiveDate,
      }) async {
    final doc = await _db.collection('requests').doc(requestId).get();
    if (!doc.exists) return;

    final header = doc.data() as Map<String, dynamic>;
    final reqTs = header['requestDate'] as Timestamp?;
    final reqDate = reqTs?.toDate();

    final update = <String, dynamic>{
      'status': 'on_delivery',
      'shippedAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };

    if (expectedReceiveDate != null) {
      update['expectedReceiveDate'] = Timestamp.fromDate(expectedReceiveDate);
    } else if (header['expectedReceiveDate'] == null) {
      final fallback = (reqDate ?? DateTime.now())
          .copyWith(hour: 0, minute: 0, second: 0, millisecond: 0)
          .add(const Duration(days: 7));
      update['expectedReceiveDate'] = Timestamp.fromDate(fallback);
    }

    await _db.collection('requests').doc(requestId).update(update);
  }

  /// 拒绝
  Future<void> rejectRequest(String requestId, {required String reason}) async {
    await _db.collection('requests').doc(requestId).update({
      'status': 'rejected',
      'rejectReason': reason,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  // ====================== A 仓：取消（如业务需要） ======================
  Future<void> cancelRequest(String requestId, {String? note}) async {
    await _db.collection('requests').doc(requestId).update({
      'status': 'rejected',
      'rejectReason': note ?? 'Cancelled by requester',
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  // ====================== 辅助：附加 __id ======================
  Map<String, dynamic> _withId(QueryDocumentSnapshot<Map<String, dynamic>> d) {
    final m = Map<String, dynamic>.from(d.data());
    m['__id'] = d.id;
    return m;
  }
}
