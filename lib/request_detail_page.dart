// lib/request_detail_page.dart
import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class RequestDetailPage extends StatelessWidget {
  const RequestDetailPage({super.key, required this.requestId});
  final String requestId;

  @override
  Widget build(BuildContext context) {
    final db = FirebaseFirestore.instance;
    final headerRef = db.collection('requests').doc(requestId);
    final itemsRef = headerRef.collection('items');

    return Scaffold(
      backgroundColor: const Color(0xFFF6F2F2),
      appBar: _TopBar(title: requestId),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: headerRef.snapshots(),
        builder: (context, headerSnap) {
          final header = headerSnap.data?.data() ?? {};
          final status = (header['status'] ?? 'pending') as String;

          // 只有在途可以编辑
          final allowEdit = status == 'on_delivery';
          // 只有在途显示“Completed”按钮
          final showCompleteBar = allowEdit;

          return Column(
            children: [
              _HeaderCard(header: header, requestId: requestId),

              // Receiving Items + 列表
              StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: itemsRef.orderBy('productName').snapshots(),
                builder: (context, snap) {
                  if (!snap.hasData) {
                    return const Padding(
                      padding: EdgeInsets.only(top: 24),
                      child: CircularProgressIndicator(),
                    );
                  }
                  final docs = snap.data!.docs;

                  // pending / completed / rejected -> 只读
                  if (!allowEdit) {
                    return _ReceivingCard(
                      count: docs.length,
                      children: [
                        for (var i = 0; i < docs.length; i++) ...[
                          _ReadOnlyItemRow(item: docs[i].data()),
                          if (i != docs.length - 1)
                            const Divider(height: 18, color: Color(0xFFE7E3E3)),
                        ],
                      ],
                    );
                  }

                  // on_delivery -> 可编辑
                  return _ReceivingCard(
                    count: docs.length,
                    children: [
                      for (var i = 0; i < docs.length; i++) ...[
                        _EditableItemRow(
                          itemRef: docs[i].reference,
                          item: docs[i].data(),
                        ),
                        if (i != docs.length - 1)
                          const Divider(height: 18, color: Color(0xFFE7E3E3)),
                      ]
                    ],
                  );
                },
              ),

              // 底部按钮：只在 on_delivery 显示
              if (showCompleteBar) _CompleteBar(headerRef: headerRef),
            ],
          );
        },
      ),
    );
  }
}

/* ====================== Header（顶卡） ====================== */

class _HeaderCard extends StatelessWidget {
  const _HeaderCard({required this.header, required this.requestId});
  final Map<String, dynamic> header;
  final String requestId;

  @override
  Widget build(BuildContext context) {
    final status = (header['status'] ?? 'pending') as String;
    final reqDate = (header['requestDate'] as Timestamp?)?.toDate();
    final expDate = (header['expectedReceiveDate'] as Timestamp?)?.toDate();
    final rcvDate = (header['receiveDate'] as Timestamp?)?.toDate(); // 新增：收货时间
    final df = DateFormat('dd-MM-yyyy');

    return _OuterCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Expanded(
              child: Text(
                'Order ID : ${header['requestId'] ?? requestId}',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
              ),
            ),
            _StatusChip(status: status),
          ]),
          const SizedBox(height: 14),

          // 第一行：Request / Expected
          Row(
            children: [
              Expanded(child: _KV('Request Date', reqDate != null ? df.format(reqDate) : '--')),
              Expanded(child: _KV('Expected Receive', expDate != null ? df.format(expDate) : '--')),
            ],
          ),

          // 若有 receiveDate（通常在 completed 后有），再显示一行
          if (rcvDate != null) ...[
            const SizedBox(height: 10),
            _KV('Receive Date', df.format(rcvDate)),
          ],
        ],
      ),
    );
  }
}

/* ====================== Receiving Card（整卡+标题） ====================== */

class _ReceivingCard extends StatelessWidget {
  const _ReceivingCard({required this.count, required this.children});
  final int count;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return _OuterCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 标题行：Receiving Items (N)  +  Quantity
          Row(
            children: [
              Expanded(
                child: Text(
                  'Receiving Items ($count)',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                ),
              ),
              const Text(
                'Quantity',
                style: TextStyle(fontSize: 16, color: Colors.black87, fontWeight: FontWeight.w600),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ...children,
        ],
      ),
    );
  }
}

/* ====================== 只读行（用于 pending/completed/rejected） ====================== */

class _ReadOnlyItemRow extends StatelessWidget {
  const _ReadOnlyItemRow({required this.item});
  final Map<String, dynamic> item;

  @override
  Widget build(BuildContext context) {
    final name = (item['productName'] ?? '') as String;
    final cat  = (item['categoryId']  ?? '') as String;
    final img  = (item['imageName']   ?? '') as String;
    final qty  = (item['qtyRequested'] as num?)?.toInt() ?? 0;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 76, height: 60,
                child: Image.asset(
                  'assets/images/$img',
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) => const Icon(Icons.image, size: 40),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name, style: const TextStyle(
                        color: Color(0xFF1482FF), fontWeight: FontWeight.w800, fontSize: 18)),
                    Text(_catText(cat), style: const TextStyle(color: Colors.black54)),
                  ],
                ),
              ),
              Text('$qty', style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800)),
            ],
          ),
        ],
      ),
    );
  }
}

/* ====================== 可编辑行（仅 on_delivery，用自动保存） ====================== */

class _EditableItemRow extends StatefulWidget {
  const _EditableItemRow({
    required this.itemRef,
    required this.item,
  });
  final DocumentReference<Map<String, dynamic>> itemRef;
  final Map<String, dynamic> item;

  @override
  State<_EditableItemRow> createState() => _EditableItemRowState();
}

class _EditableItemRowState extends State<_EditableItemRow> {
  late String _status; // received / damaged / returned
  late int _qtyRequested;
  int? _qtyReceived, _qtyDamaged, _qtyReturned;
  String? _reason;

  final _debouncer = _Debouncer(const Duration(milliseconds: 350));
  bool _isFresh = false; // 首次进入在途且无状态时写默认

  @override
  void initState() {
    super.initState();
    _status       = (widget.item['itemStatus'] as String?) ?? 'received';
    _qtyRequested = (widget.item['qtyRequested'] as num?)?.toInt() ?? 0;
    _qtyReceived  = (widget.item['qtyReceived']  as num?)?.toInt();
    _qtyDamaged   = (widget.item['qtyDamaged']   as num?)?.toInt();
    _qtyReturned  = (widget.item['qtyReturned']  as num?)?.toInt();
    _reason       =  widget.item['returnReason'] as String?;

    if (widget.item['itemStatus'] == null) {
      _isFresh = true;
      _status = 'received';
      _qtyReceived = _qtyRequested;
      _saveDefaultOnce();
    } else if (_status == 'received' && _qtyReceived == null) {
      _qtyReceived = _qtyRequested; // 仅本地显示
    }
  }

  Future<void> _saveDefaultOnce() async {
    try {
      await widget.itemRef.update({
        'itemStatus': 'received',
        'qtyReceived': _qtyRequested,
        'qtyDamaged' : null,
        'qtyReturned': null,
        'returnReason': null,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } finally {
      _isFresh = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final name = (widget.item['productName'] ?? '') as String;
    final cat  = (widget.item['categoryId']  ?? '') as String;
    final img  = (widget.item['imageName']   ?? '') as String;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 76, height: 60,
                child: Image.asset(
                  'assets/images/$img',
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) => const Icon(Icons.image, size: 40),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name, style: const TextStyle(
                        color: Color(0xFF1482FF), fontWeight: FontWeight.w800, fontSize: 18)),
                    Text(_catText(cat), style: const TextStyle(color: Colors.black54)),
                  ],
                ),
              ),
              Text('$_qtyRequested', style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800)),
            ],
          ),
          const SizedBox(height: 10),

          Align(
            alignment: Alignment.centerRight,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                // Status
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('Status :  ', style: TextStyle(fontWeight: FontWeight.w700)),
                    _statusDropdown(),
                  ],
                ),
                const SizedBox(height: 8),

                // Quantity
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('Quantity :  ', style: TextStyle(fontWeight: FontWeight.w700)),
                    SizedBox(
                      width: 110,
                      child: _UnderlineNumber(
                        value: switch (_status) {
                          'received' => _qtyReceived ?? 0,
                          'damaged'  => _qtyDamaged  ?? 0,
                          _          => _qtyReturned ?? 0,
                        },
                        onChanged: (v) {
                          // clamp：received 0..req；damaged/returned 1..req
                          int min = (_status == 'damaged' || _status == 'returned') ? 1 : 0;
                          int max = _qtyRequested;
                          final vv = v.clamp(min, max);
                          setState(() {
                            if (_status == 'received') _qtyReceived = vv;
                            if (_status == 'damaged')  _qtyDamaged  = vv;
                            if (_status == 'returned') _qtyReturned = vv;
                          });
                          _autoSave();
                        },
                      ),
                    ),
                  ],
                ),

                if (_status == 'returned') ...[
                  const SizedBox(height: 8),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('Reason :  ', style: TextStyle(fontWeight: FontWeight.w700)),
                      SizedBox(
                        width: 180,
                        child: DropdownButtonFormField<String>(
                          value: _reason ?? 'Wrong Item',
                          decoration: _underlineInputDecoration(),
                          items: const [
                            DropdownMenuItem(value: 'Wrong Item', child: Text('Wrong Item')),
                            DropdownMenuItem(value: 'Box Broken', child: Text('Box Broken')),
                            DropdownMenuItem(value: 'Quality Issue', child: Text('Quality Issue')),
                          ],
                          onChanged: (v) { setState(() => _reason = v); _autoSave(); },
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _statusDropdown() {
    return DropdownButtonHideUnderline(
      child: Container(
        height: 36,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          border: Border.all(color: const Color(0xFFDDDDDD)),
          borderRadius: BorderRadius.circular(6),
        ),
        child: DropdownButton<String>(
          value: _status,
          icon: const Icon(Icons.keyboard_arrow_down),
          items: const [
            DropdownMenuItem(value: 'received', child: _StatusChoice(icon: '✔', text: 'Received', color: Colors.green)),
            DropdownMenuItem(value: 'damaged',  child: _StatusChoice(icon: '✖', text: 'Damaged',  color: Colors.red)),
            DropdownMenuItem(value: 'returned', child: _StatusChoice(icon: '↩', text: 'Returned', color: Colors.orange)),
          ],
          onChanged: (v) {
            if (v == null) return;
            setState(() {
              _status = v;
              if (v == 'received') {
                _qtyReceived = _qtyRequested;
                _qtyDamaged = _qtyReturned = null;
                _reason = null;
              } else if (v == 'damaged') {
                _qtyDamaged = (_qtyDamaged == null || _qtyDamaged == 0) ? 1 : _qtyDamaged;
                _qtyReceived = _qtyReturned = null;
                _reason = null;
              } else { // returned
                _qtyReturned = (_qtyReturned == null || _qtyReturned == 0) ? 1 : _qtyReturned;
                _qtyReceived = _qtyDamaged = null;
                _reason ??= 'Wrong Item';
              }
            });
            _autoSave();
          },
        ),
      ),
    );
  }

  void _autoSave() {
    if (_isFresh) return; // 首次默认写入另行处理
    _debouncer.run(() async {
      final patch = <String, dynamic>{
        'itemStatus' : _status,
        'updatedAt'  : FieldValue.serverTimestamp(),
        'qtyReceived': null,
        'qtyDamaged' : null,
        'qtyReturned': null,
        'returnReason': null,
      };
      if (_status == 'received') {
        patch['qtyReceived'] = _qtyReceived ?? _qtyRequested;
      } else if (_status == 'damaged') {
        patch['qtyDamaged']  = _qtyDamaged  ?? 1;
      } else {
        patch['qtyReturned'] = _qtyReturned ?? 1;
        patch['returnReason'] = _reason ?? 'Wrong Item';
      }
      await widget.itemRef.update(patch);
    });
  }

  static InputDecoration _underlineInputDecoration() => const InputDecoration(
    isDense: true,
    contentPadding: EdgeInsets.only(bottom: 4),
    enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.black54, width: 1.4)),
    focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.black87, width: 1.6)),
  );
}

/* ====================== Completed 按钮（只在 on_delivery 时出现） ====================== */

class _CompleteBar extends StatelessWidget {
  const _CompleteBar({required this.headerRef});
  final DocumentReference<Map<String, dynamic>> headerRef;

  bool _itemValid(Map<String, dynamic> m) {
    final status = m['itemStatus'] as String?;
    final req = (m['qtyRequested'] as num?)?.toInt() ?? 0;

    if (status == 'received') {
      final v = (m['qtyReceived'] as num?)?.toInt() ?? 0;
      return v >= 0 && v <= req; // 若你想 received 必须 ≥1，把 0 改成 1
    }
    if (status == 'damaged') {
      final v = (m['qtyDamaged'] as num?)?.toInt() ?? 0;
      return v >= 1 && v <= req;
    }
    if (status == 'returned') {
      final v = (m['qtyReturned'] as num?)?.toInt() ?? 0;
      return v >= 1 && v <= req;
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final itemsRef = headerRef.collection('items');
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: itemsRef.snapshots(),
      builder: (context, snap) {
        final docs = snap.data?.docs ?? [];
        final itemsOK = docs.isNotEmpty && docs.every((d) => _itemValid(d.data()));

        return SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 6, 16, 12),
            child: Center(
              child: InkWell(
                onTap: !itemsOK
                    ? null
                    : () async {
                  await headerRef.update({
                    'status': 'completed',
                    'receiveDate': FieldValue.serverTimestamp(),
                    'updatedAt': FieldValue.serverTimestamp(),
                  });
                  if (context.mounted) Navigator.pop(context);
                },
                borderRadius: BorderRadius.circular(28),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 12),
                  decoration: BoxDecoration(
                    color: itemsOK ? const Color(0xFF7ED957) : const Color(0xFFBDBDBD),
                    borderRadius: BorderRadius.circular(28),
                    boxShadow: const [BoxShadow(color: Color(0x26000000), blurRadius: 4, offset: Offset(0, 2))],
                  ),
                  child: const Text('Completed',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/* ====================== 通用小部件 ====================== */

class _TopBar extends StatelessWidget implements PreferredSizeWidget {
  const _TopBar({required this.title});
  final String title;
  @override
  Size get preferredSize => const Size.fromHeight(60);
  @override
  Widget build(BuildContext context) {
    return AppBar(
      backgroundColor: const Color(0xFFE63936),
      elevation: 0,
      centerTitle: true,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back, color: Colors.white, size: 28),
        onPressed: () => Navigator.pop(context),
      ),
      title: Text(
        title,
        style: const TextStyle(
            color: Colors.white, fontWeight: FontWeight.w800, fontSize: 28, letterSpacing: .5),
      ),
    );
  }
}

class _OuterCard extends StatelessWidget {
  const _OuterCard({required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 12, 12, 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(6),
        boxShadow: const [BoxShadow(color: Color(0x1A000000), blurRadius: 6, offset: Offset(0, 2))],
      ),
      child: child,
    );
  }
}

class _KV extends StatelessWidget {
  const _KV(this.k, this.v);
  final String k, v;
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(k, style: const TextStyle(color: Colors.black54, fontSize: 14, fontWeight: FontWeight.w600)),
        const SizedBox(height: 4),
        Text(v, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
      ],
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});
  final String status;
  @override
  Widget build(BuildContext context) {
    String text = 'Pending';
    Color color = Colors.blue;
    switch (status) {
      case 'on_delivery':
        text = 'On Delivery';
        color = Colors.orange;
        break;
      case 'completed':
        text = 'Completed';
        color = Colors.green;
        break;
      case 'rejected':
        text = 'Rejected';
        color = Colors.red;
        break;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(color: color.withOpacity(.12), borderRadius: BorderRadius.circular(8)),
      child: Text(text, style: TextStyle(color: color, fontWeight: FontWeight.w800, fontSize: 16)),
    );
  }
}

class _StatusChoice extends StatelessWidget {
  const _StatusChoice({required this.icon, required this.text, required this.color});
  final String icon, text; final Color color;
  @override
  Widget build(BuildContext context) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Text(icon, style: TextStyle(color: color, fontSize: 16, fontWeight: FontWeight.w900)),
      const SizedBox(width: 6),
      Text(text, style: TextStyle(color: color, fontWeight: FontWeight.w700)),
    ]);
  }
}

class _UnderlineNumber extends StatefulWidget {
  const _UnderlineNumber({required this.value, required this.onChanged});
  final int value; final ValueChanged<int> onChanged;
  @override
  State<_UnderlineNumber> createState() => _UnderlineNumberState();
}
class _UnderlineNumberState extends State<_UnderlineNumber> {
  late final TextEditingController _c;
  @override
  void initState() { super.initState(); _c = TextEditingController(text: widget.value.toString()); }
  @override
  void didUpdateWidget(covariant _UnderlineNumber oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value) _c.text = widget.value.toString();
  }
  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _c,
      keyboardType: TextInputType.number,
      style: const TextStyle(fontSize: 16),
      decoration: const InputDecoration(
        isDense: true,
        contentPadding: EdgeInsets.only(bottom: 4),
        enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.black54, width: 1.4)),
        focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.black87, width: 1.6)),
      ),
      onChanged: (s) => widget.onChanged(int.tryParse(s) ?? 0),
    );
  }
}

class _Debouncer {
  _Debouncer(this.delay);
  final Duration delay;
  Timer? _t;
  void run(void Function() f) {
    _t?.cancel();
    _t = Timer(delay, f);
  }
}

/* ====================== 顶层工具函数：分类名 ====================== */
String _catText(String id) {
  switch (id) {
    case 'engine_components':
      return 'Engine Components';
    case 'braking_system':
      return 'Braking System';
    case 'body_exterior':
      return 'Body & Exterior';
    case 'electrical_electronics':
      return 'electrical_electronics';
    default:
      return id;
  }
}
