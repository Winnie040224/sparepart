// lib/new_request_page.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'main.dart';                     // kFromWarehouseId, kCurrentUserId
import 'services/request_service.dart'; // createRequestAutoId()

/* ------------ items 的数据模型 ------------ */
class RequestedItem {
  RequestedItem({
    required this.productId,
    required this.productName,
    required this.imageName,
    required this.categoryId,
    required this.qtyRequested,
  });

  final String productId, productName, imageName, categoryId;
  final int qtyRequested;

  Map<String, dynamic> toMap() => {
    'productId': productId,
    'productName': productName,
    'imageName': imageName,
    'categoryId': categoryId,
    'qtyRequested': qtyRequested,
  };
}

/* ============================ 页面 ============================ */

class NewRequestPage extends StatefulWidget {
  const NewRequestPage({super.key});

  @override
  State<NewRequestPage> createState() => _NewRequestPageState();
}

class _NewRequestPageState extends State<NewRequestPage> {
  static const int _maxItems = 5; // 最多 5 种不同产品
  static const int _maxQtyPerLine = 200;

  final _db = FirebaseFirestore.instance;

  final _requesterCtrl = TextEditingController(text: kCurrentUserId);
  final DateTime _date = DateTime.now(); // 直接用当天日期
  String? _toWarehouseId; // 目的仓（不包含自己仓）
  bool _busy = false;

  final List<RequestedItem> _items = [];

  @override
  void dispose() {
    _requesterCtrl.dispose();
    super.dispose();
  }

  // 相同 productId 合并数量（封顶 200）
  void _upsertItem(RequestedItem newItem) {
    final idx = _items.indexWhere((e) => e.productId == newItem.productId);
    if (idx >= 0) {
      final old = _items[idx];
      final summed = old.qtyRequested + newItem.qtyRequested;
      final capped = summed.clamp(1, _maxQtyPerLine);
      if (summed > _maxQtyPerLine) {
        _snack('Quantity for "${old.productName}" cannot exceed $_maxQtyPerLine. Capped at $_maxQtyPerLine.');
      }
      _items[idx] = RequestedItem(
        productId: old.productId,
        productName: old.productName,
        imageName: old.imageName,
        categoryId: old.categoryId,
        qtyRequested: capped,
      );
    } else {
      _items.add(newItem);
    }
  }

  Future<void> _openAddPartSheet() async {
    // 限制“不同产品种数”最多 5；已存在的产品可以继续合并数量
    if (_items.length >= _maxItems) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('You can add up to 5 different products only.')),
      );
      return;
    }

    final res = await showModalBottomSheet<RequestedItem>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _SelectPartSheet(),
    );

    if (res != null) {
      final exists = _items.any((e) => e.productId == res.productId);
      if (!exists && _items.length >= _maxItems) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('You can add up to 5 different products only.')),
        );
        return;
      }
      setState(() => _upsertItem(res));
    }
  }

  Future<void> _submit() async {
    if (_toWarehouseId == null) {
      _snack('Please select "Requester To".');
      return;
    }
    if (_items.isEmpty) {
      _snack('Please add at least 1 part.');
      return;
    }

    setState(() => _busy = true);
    try {
      final requestId = await RequestService.instance.createRequestAutoIdByScanning(
        fromWarehouseId: kFromWarehouseId,
        toWarehouseId: _toWarehouseId!,
        createdByUserId: kCurrentUserId,
        requestDate: DateTime.now(),
        items: _items.map((e) => e.toMap()).toList(),
        expectedDays: 7,
      );

      if (!mounted) return;
      _snack('Created $requestId');
      setState(() {
        _items.clear();
        _toWarehouseId = null;
      });
    } catch (e) {
      _snack('Submit failed: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _snack(String m) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

  @override
  Widget build(BuildContext context) {
    final df = DateFormat('dd-MM-yyyy');
    final dateText = df.format(_date);
    final dateCtrl = TextEditingController(text: dateText);

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      children: [
        // 表单卡片（圆角+红色胶囊标题）
        Container(
          margin: const EdgeInsets.only(top: 8),
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(22),
            boxShadow: const [
              BoxShadow(
                color: Color(0x14000000),
                blurRadius: 8,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            children: [
              // 胶囊标题
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFFE63936),
                  borderRadius: BorderRadius.circular(22),
                ),
                child: const Center(
                  child: Text(
                    'Parts Request Form',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 18,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 14),

              // Requester Name
              _LabeledField(
                label: 'Requester Name',
                child: TextField(
                  controller: _requesterCtrl,
                  decoration: const InputDecoration(
                    isDense: true,
                    border: UnderlineInputBorder(),
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // Date（同一行，有下划线，只读）
              _LabeledField(
                label: 'Date',
                child: TextField(
                  controller: dateCtrl,
                  readOnly: true,
                  enableInteractiveSelection: false,
                  decoration: const InputDecoration(
                    isDense: true,
                    border: UnderlineInputBorder(),
                  ),
                  style: const TextStyle(fontSize: 16),
                ),
              ),
              const SizedBox(height: 12),

              // Requester To（排除自己仓）
              _LabeledField(
                label: 'Requester To',
                child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: _db.collection('warehouses').orderBy(FieldPath.documentId).snapshots(),
                  builder: (context, snap) {
                    final docs = (snap.data?.docs ?? []).where((d) => d.id != kFromWarehouseId).toList();
                    return DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        isExpanded: true,
                        value: _toWarehouseId,
                        hint: const Text('Select a warehouse'),
                        items: docs
                            .map((d) => DropdownMenuItem(
                          value: d.id,
                          child: Text('${d.data()['name'] ?? d.id} (${d.id})'),
                        ))
                            .toList(),
                        onChanged: (v) => setState(() => _toWarehouseId = v),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 16),

              // Parts Requested 表格
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Parts Requested',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(color: const Color(0xFF1482FF)),
                ),
              ),
              const SizedBox(height: 8),
              _partsTable(context),

              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _busy ? null : _submit,
                  child: const Text('Submit Request'),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// 表格（带边框）。空表时第一行 Name 单元格显示绿色 Add 按钮。
  Widget _partsTable(BuildContext context) {
    final headerStyle = Theme.of(context).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700);

    final colWidths = <int, TableColumnWidth>{
      0: const FixedColumnWidth(56), // No.
      1: const FlexColumnWidth(3), // Name
      2: const FlexColumnWidth(2), // ID
      3: const FixedColumnWidth(90), // Quantity
    };

    final rows = <TableRow>[
      TableRow(
        decoration: const BoxDecoration(),
        children: [
          _cellText('No.', headerStyle, pad: 8),
          _cellText('Name', headerStyle, pad: 8),
          _cellText('ID', headerStyle, pad: 8),
          _cellText('Quantity', headerStyle, pad: 8),
        ],
      ),
    ];

    if (_items.isEmpty) {
      rows.add(
        TableRow(
          children: [
            _cellText('', null),
            Padding(
              padding: const EdgeInsets.all(6),
              child: Align(
                alignment: Alignment.centerLeft,
                child: InkWell(
                  onTap: _openAddPartSheet,
                  borderRadius: BorderRadius.circular(6),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFF7ED957), // 绿色小胶囊
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Text(
                      'Add',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            _cellText('', null),
            _cellText('', null),
          ],
        ),
      );
    } else {
      for (var i = 0; i < _items.length; i++) {
        final it = _items[i];
        rows.add(
          TableRow(
            children: [
              _cellText('${i + 1}', null),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
                child: Row(
                  children: [
                    Expanded(child: Text(it.productName)),
                    IconButton(
                      tooltip: 'Remove',
                      onPressed: () => setState(() => _items.removeAt(i)),
                      icon: const Icon(Icons.close, size: 18),
                      splashRadius: 18,
                    ),
                  ],
                ),
              ),
              _cellText(it.productId, null),
              _cellText('${it.qtyRequested}', null),
            ],
          ),
        );
      }

      // 最后一行也给一个 Add 入口（绿色同款）
      rows.add(
        TableRow(
          children: [
            _cellText('', null),
            Padding(
              padding: const EdgeInsets.all(6),
              child: Align(
                alignment: Alignment.centerLeft,
                child: InkWell(
                  onTap: _openAddPartSheet,
                  borderRadius: BorderRadius.circular(6),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFF7ED957),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Text(
                      'Add more',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            _cellText('', null),
            _cellText('', null),
          ],
        ),
      );

      // 如果达到 5 种，提示一条灰色说明（可选）
      if (_items.length >= _maxItems) {
        rows.add(
          TableRow(
            children: [
              _cellText('', null),
              Padding(
                padding: const EdgeInsets.only(left: 6, top: 4, bottom: 8),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.black12,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  child: const Text(
                    'Max 5 items',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ),
              _cellText('', null),
              _cellText('', null),
            ],
          ),
        );
      }
    }

    return Table(
      columnWidths: colWidths,
      border: TableBorder.all(color: Colors.black54, width: 1),
      defaultVerticalAlignment: TableCellVerticalAlignment.middle,
      children: rows,
    );
  }

  Widget _cellText(String t, TextStyle? style, {double pad = 6}) {
    return Padding(
      padding: EdgeInsets.all(pad),
      child: Text(t, style: style),
    );
  }
}

/* ----------------------- 表单标签与控件 ----------------------- */

class _LabeledField extends StatelessWidget {
  const _LabeledField({required this.label, required this.child});
  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 13, color: Colors.black54, height: 1)),
        const SizedBox(height: 6),
        child,
      ],
    );
  }
}

/* ======================= 选择 Part 的弹窗（底部弹出） ======================= */

class _SelectPartSheet extends StatefulWidget {
  const _SelectPartSheet();

  @override
  State<_SelectPartSheet> createState() => _SelectPartSheetState();
}

class _SelectPartSheetState extends State<_SelectPartSheet> {
  static const int _maxQty = 200;

  final _db = FirebaseFirestore.instance;

  String? _selectedDocId; // products 文档 id
  Map<String, dynamic>? _selectedData;

  int _qty = 1;
  final _qtyCtrl = TextEditingController(text: '1');

  @override
  void dispose() {
    _qtyCtrl.dispose();
    super.dispose();
  }

  void _setQty(int v) {
    final vv = v.clamp(1, _maxQty);
    // 超过上限时给个 Snack 提醒（只在用户产生变化时提示）
    if (v > _maxQty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Quantity cannot exceed 200.')),
      );
    }
    setState(() {
      _qty = vv;
      _qtyCtrl.text = vv.toString();
    });
  }

  void _onQtyChangeText(String s) {
    final v = int.tryParse(s) ?? 0;
    _setQty(v <= 0 ? 1 : v);
  }

  void _quick(int v) => _setQty(v);

  @override
  Widget build(BuildContext context) {
    final radius = const Radius.circular(22);

    return Material(
      color: Colors.transparent,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.only(topLeft: radius, topRight: radius),
          boxShadow: const [BoxShadow(color: Color(0x33000000), blurRadius: 12, offset: Offset(0, -2))],
        ),
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          bottom: 16 + MediaQuery.of(context).viewInsets.bottom,
          top: 12,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 胶囊标题
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFFE63936),
                borderRadius: BorderRadius.circular(22),
              ),
              child: const Center(
                child: Text(
                  'Select Part',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 18),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Part 下拉（来自 products 集合）——显示 name (id)
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const Text('Part:  ', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                Expanded(
                  child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                    stream: _db.collection('products').orderBy('name').snapshots(),
                    builder: (context, snap) {
                      final docs = snap.data?.docs ?? [];
                      return DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          isExpanded: true,
                          value: _selectedDocId,
                          hint: const Text('Select Part'),
                          items: docs.map((d) {
                            final m = d.data();
                            final id = (m['id'] ?? d.id).toString();
                            final name = (m['name'] ?? d.id).toString();
                            return DropdownMenuItem(
                              value: d.id,
                              child: Text('$name ($id)'),
                            );
                          }).toList(),
                          onChanged: (v) {
                            if (v == null) return;
                            final d = docs.firstWhere((e) => e.id == v);
                            setState(() {
                              _selectedDocId = v;
                              _selectedData = d.data();
                            });
                          },
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // 数量：- [输入框] + ；以及快捷 Chip（最大 200）
            Row(
              children: [
                const Text('Quantity  :  ', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                _StepBtn(icon: Icons.remove, onTap: () => _setQty(_qty - 1)),
                const SizedBox(width: 8),
                SizedBox(
                  width: 80,
                  child: TextField(
                    controller: _qtyCtrl,
                    textAlign: TextAlign.center,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      isDense: true,
                      contentPadding: EdgeInsets.symmetric(vertical: 6),
                      border: UnderlineInputBorder(),
                    ),
                    onChanged: _onQtyChangeText,
                  ),
                ),
                const SizedBox(width: 8),
                _StepBtn(icon: Icons.add, onTap: () => _setQty(_qty + 1)),
              ],
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              children: [
                for (final v in const [50, 100, 150, 200])
                  ChoiceChip(
                    label: Text('$v'),
                    selected: _qty == v,
                    onSelected: (_) => _quick(v),
                  )
              ],
            ),
            const SizedBox(height: 18),

            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancel'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    onPressed: _selectedData == null || _qty <= 0
                        ? null
                        : () {
                      final m = _selectedData!;
                      final id = (m['id'] ?? _selectedDocId).toString();
                      final item = RequestedItem(
                        productId: id,
                        productName: (m['name'] ?? 'Unknown').toString(),
                        imageName: (m['imageName'] ?? 'no_image.png').toString(),
                        categoryId: (m['categoryId'] ?? '').toString(),
                        qtyRequested: _qty,
                      );
                      Navigator.pop(context, item);
                    },
                    child: const Text('Add'),
                  ),
                ),
              ],
            )
          ],
        ),
      ),
    );
  }
}

class _StepBtn extends StatelessWidget {
  const _StepBtn({required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkResponse(
      onTap: onTap,
      radius: 22,
      child: Container(
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          border: Border.all(color: Colors.black26),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, size: 18),
      ),
    );
  }
}
