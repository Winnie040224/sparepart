// add_stock_page.dart
import 'package:flutter/material.dart';

class AddStockPage extends StatefulWidget {
  @override
  _AddStockPageState createState() => _AddStockPageState();
}

class _AddStockPageState extends State<AddStockPage> {
  final TextEditingController _barcodeController = TextEditingController();
  final TextEditingController _quantityController = TextEditingController();

  String? itemName;
  List<String> racks = ['Rack A', 'Rack B', 'Rack C'];
  String? selectedRack;
  Map<String, int> rackSpaces = {
    'Rack A': 10,
    'Rack B': 3,
    'Rack C': 5,
  };

  void scanOrEnterBarcode(String code) {
    // 假设用 barcode 查数据库，这里用 mock data
    setState(() {
      itemName = getItemNameByBarcode(code);
      selectedRack = getMostAvailableRack();
    });
  }

  String getItemNameByBarcode(String code) {
    // 模拟数据库查询
    Map<String, String> mockItemDB = {
      '123456': 'Brake Pad',
      '789012': 'Air Filter',
    };
    return mockItemDB[code] ?? 'Unknown Item';
  }

  String getMostAvailableRack() {
    rackSpaces.entries.toList().sort((a, b) => b.value.compareTo(a.value));
    return rackSpaces.entries.first.key;
  }

  void submit() {
    String barcode = _barcodeController.text;
    String rack = selectedRack ?? 'Rack A';
    String qty = _quantityController.text;

    if (barcode.isEmpty || qty.isEmpty || itemName == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Please complete all fields")),
      );
      return;
    }

    // 在这里可以把数据发送到数据库或API
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("Stock added to $rack successfully")),
    );

    Navigator.pop(context); // 回首页
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Add New Stock")),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: _barcodeController,
              decoration: InputDecoration(
                labelText: "Scan or Enter Barcode",
                suffixIcon: IconButton(
                  icon: Icon(Icons.qr_code),
                  onPressed: () {
                    // 可以整合 barcode_scan 包
                    // 模拟扫描出一个 ID：
                    _barcodeController.text = '123456';
                    scanOrEnterBarcode('123456');
                  },
                ),
              ),
              onSubmitted: scanOrEnterBarcode,
            ),
            SizedBox(height: 20),

            if (itemName != null)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("Item: $itemName", style: TextStyle(fontSize: 16)),
                  SizedBox(height: 10),
                  Text("Select Rack:"),
                  DropdownButton<String>(
                    value: selectedRack,
                    onChanged: (val) => setState(() => selectedRack = val),
                    items: racks.map((rack) {
                      return DropdownMenuItem(
                        value: rack,
                        child: Text("$rack (empty: ${rackSpaces[rack]})"),
                      );
                    }).toList(),
                  ),
                  TextField(
                    controller: _quantityController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(labelText: "Enter Quantity"),
                  ),
                  SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: submit,
                    child: Text("Add Stock"),
                  ),
                ],
              )
          ],
        ),
      ),
    );
  }
}
