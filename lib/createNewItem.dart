import 'package:flutter/material.dart';
import 'package:flutter_barcode_scanner/flutter_barcode_scanner.dart';

class CreateNewItemPage extends StatefulWidget {
  @override
  _CreateNewItemPageState createState() => _CreateNewItemPageState();
}

class _CreateNewItemPageState extends State<CreateNewItemPage> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController nameController = TextEditingController();
  final TextEditingController descController = TextEditingController();
  final TextEditingController barcodeController = TextEditingController();

  String? selectedRack;
  final List<String> availableRacks = ['Rack A', 'Rack B', 'Rack C'];

  // 扫描条形码的方法
  Future<void> scanBarcode() async {
    String scanResult = await FlutterBarcodeScanner.scanBarcode(
      '#ff6666', // 扫描框颜色
      'Cancel',
      true,
      ScanMode.BARCODE,
    );

    if (scanResult != '-1') {
      setState(() {
        barcodeController.text = scanResult;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Create New Item'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              TextFormField(
                controller: nameController,
                decoration: InputDecoration(labelText: 'Item Name'),
                validator: (value) =>
                value!.isEmpty ? 'Please enter item name' : null,
              ),
              SizedBox(height: 10),
              TextFormField(
                controller: descController,
                decoration: InputDecoration(labelText: 'Item Description'),
                validator: (value) =>
                value!.isEmpty ? 'Please enter description' : null,
              ),
              SizedBox(height: 10),
              TextFormField(
                controller: barcodeController,
                decoration: InputDecoration(
                  labelText: 'Bar Code',
                  suffixIcon: IconButton(
                    icon: Icon(Icons.qr_code_scanner),
                    onPressed: scanBarcode, // 点击按钮启动扫描
                  ),
                ),
              ),
              SizedBox(height: 10),
              DropdownButtonFormField<String>(
                value: selectedRack,
                hint: Text('Select Rack'),
                onChanged: (value) {
                  setState(() {
                    selectedRack = value;
                  });
                },
                items: availableRacks.map((rack) {
                  return DropdownMenuItem(
                    value: rack,
                    child: Text(rack),
                  );
                }).toList(),
                validator: (value) =>
                value == null ? 'Please select a rack' : null,
              ),
              SizedBox(height: 20),
              ElevatedButton(
                onPressed: () {
                  if (_formKey.currentState!.validate()) {
                    print("Item Created:");
                    print("Name: ${nameController.text}");
                    print("Desc: ${descController.text}");
                    print("Barcode: ${barcodeController.text}");
                    print("Rack: $selectedRack");

                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Item created successfully!')),
                    );

                    Navigator.pop(context);
                  }
                },
                child: Text('Create Item'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
