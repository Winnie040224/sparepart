import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'new_request_page.dart';

class SelectPartPage extends StatefulWidget {
  const SelectPartPage({super.key});
  @override
  State<SelectPartPage> createState() => _SelectPartPageState();
}

class _SelectPartPageState extends State<SelectPartPage> {
  final _db = FirebaseFirestore.instance;
  String? _pid, _pname, _img, _cat;
  int _qty = 1;

  @override
  Widget build(BuildContext context) {
    final titleStyle = Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700);
    return Scaffold(
      appBar: AppBar(title: const Text('Part Request')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(children: [
          Center(child: Text('Select Part', style: titleStyle)),
          const SizedBox(height: 16),
          StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: _db.collection('products').orderBy('name').snapshots(),
            builder: (context, snap) {
              final docs = snap.data?.docs ?? [];
              return InputDecorator(
                decoration: const InputDecoration(labelText: 'Part', border: OutlineInputBorder()),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _pid,
                    isExpanded: true,
                    hint: const Text('Select Part'),
                    items: docs.map((d) {
                      final m = d.data();
                      final id = d.id;
                      final name = m['name'] ?? id;
                      final img = m['imageName'] ?? '';
                      final cat = m['categoryId'] ?? '';
                      return DropdownMenuItem(
                        value: id,
                        onTap: () {
                          _pname = name;
                          _img = img;
                          _cat = cat;
                        },
                        child: Text('$name ($id)'),
                      );
                    }).toList(),
                    onChanged: (v) => setState(() => _pid = v),
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 16),
          Row(children: [
            Expanded(child: Text('Quantity :', style: Theme.of(context).textTheme.titleMedium)),
            IconButton(onPressed: () => setState(() => _qty = (_qty > 1) ? _qty - 1 : 1),
                icon: const Icon(Icons.remove_circle_outline)),
            SizedBox(width: 64, child: Center(child: Text('$_qty', style: const TextStyle(fontSize: 18)))),
            IconButton(onPressed: () => setState(() => _qty++), icon: const Icon(Icons.add_circle_outline)),
          ]),
          const Spacer(),
          Row(children: [
            Expanded(child: OutlinedButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel'))),
            const SizedBox(width: 12),
            Expanded(
              child: FilledButton(
                onPressed: (_pid == null)
                    ? null
                    : () {
                  final item = RequestedItem(
                    productId: _pid!,
                    productName: _pname ?? _pid!,
                    imageName: _img ?? '',
                    categoryId: _cat ?? '',
                    qtyRequested: _qty,
                  );
                  Navigator.pop(context, item);
                },
                child: const Text('Add'),
              ),
            ),
          ])
        ]),
      ),
    );
  }
}
