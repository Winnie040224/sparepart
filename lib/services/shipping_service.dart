// lib/services/shipping_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';

class ShippingService {
  ShippingService._();
  static final instance = ShippingService._();
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  /// 把 pending 的请求“发货”：
  /// - 扣减 fromWarehouseId 的库存（stocks/{fromWarehouseId}_{productId}）
  /// - 写 movements 流水（可选）
  /// - 更新 requests/{requestId} 为 on_delivery，并写 shippedAt
  ///
  /// [requireAllScanned] = true 时，若任一 item.scanCompleted != true 会报错
  Future<void> shipAndMarkOnDelivery({
    required String requestId,
    required String fromWarehouseId,
    required String toWarehouseId,
    bool requireAllScanned = true,
  }) async {
    final requestDocRef = _db.collection('requests').doc(requestId);

    // 事务外先把 items 文档列表取出来（事务里不能 get collection）
    final itemsQuerySnap = await requestDocRef.collection('items').get();
    if (itemsQuerySnap.docs.isEmpty) {
      throw 'No items to ship';
    }
    final itemRefs = itemsQuerySnap.docs.map((d) => d.reference).toList();

    await _db.runTransaction((tx) async {
      // 读单头
      final reqSnap = await tx.get(requestDocRef);
      if (!reqSnap.exists) throw 'Request not found';
      final req = reqSnap.data() as Map<String, dynamic>;
      final status = (req['status'] ?? 'pending').toString().toLowerCase();
      if (status != 'pending') {
        throw 'Request already processed (status: $status)';
      }

      // 逐行处理 item
      for (final itemRef in itemRefs) {
        final itemSnap = await tx.get(itemRef);
        if (!itemSnap.exists) continue;
        final m = itemSnap.data() as Map<String, dynamic>;

        // 可选：要求所有条目已 scanCompleted
        if (requireAllScanned && (m['scanCompleted'] ?? false) != true) {
          throw 'Some items are not scanned yet';
        }

        final String productId = (m['productId'] ?? m['id'] ?? '').toString();
        final int qtyReq = _asInt(m['qtyRequested']);
        if (productId.isEmpty || qtyReq <= 0) continue;

        // 读取 fromWarehouse 的库存文档
        final stockRef = _db.collection('stocks').doc('${fromWarehouseId}_$productId');
        final stockSnap = await tx.get(stockRef);
        if (!stockSnap.exists) {
          throw 'Stock not found for ${fromWarehouseId}_$productId';
        }
        final stock = stockSnap.data() as Map<String, dynamic>;
        final List<dynamic> locs = (stock['locations'] ?? []) as List<dynamic>;

        // 计算总量并校验
        int total = 0;
        for (final x in locs) {
          total += _asInt((x as Map)['quantity']);
        }
        if (total < qtyReq) {
          throw 'Insufficient stock for $productId (need $qtyReq, have $total)';
        }

        // 扣减（按顺序扣）
        int remain = qtyReq;
        final newLocs = <Map<String, dynamic>>[];
        for (final x in locs) {
          final map = Map<String, dynamic>.from(x as Map);
          int q = _asInt(map['quantity']);
          if (remain > 0 && q > 0) {
            final take = q >= remain ? remain : q;
            q -= take;
            remain -= take;
            map['quantity'] = q;
          }
          newLocs.add(map);
        }

        // 写回库存
        tx.update(stockRef, {
          'locations': newLocs,
          'updatedAt': FieldValue.serverTimestamp(),
        });

        // 标记行项目为已拣/已出（可选字段）
        tx.update(itemRef, {
          'pickedQty': qtyReq,
          'pickedAt': FieldValue.serverTimestamp(),
        });

        // 记录出库流水（可选）
        final moveRef = _db.collection('movements').doc();
        tx.set(moveRef, {
          'type': 'issue',
          'requestId': requestId,
          'fromWarehouseId': fromWarehouseId,
          'toWarehouseId': toWarehouseId,
          'productId': productId,
          'quantity': qtyReq,
          'createdAt': FieldValue.serverTimestamp(),
        });
      }

      // 更新单头为 on_delivery
      tx.update(requestDocRef, {
        'status': 'on_delivery',
        'shippedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    });
  }

  /// 安全把 dynamic 转 int
  static int _asInt(dynamic v) {
    if (v == null) return 0;
    if (v is int) return v;
    if (v is num) return v.toInt();
    if (v is String) return int.tryParse(v) ?? 0;
    return 0;
  }
}
