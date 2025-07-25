import 'package:flutter/material.dart';

import 'home.dart';

class ItemDetailPage extends StatelessWidget {
  final Item item;

  const ItemDetailPage({Key? key, required this.item}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('${item.name} Details'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Item ID: ${item.id}", style: TextStyle(fontSize: 20)),
            SizedBox(height: 10),
            Text("Item Name: ${item.name}", style: TextStyle(fontSize: 18)),
          ],
        ),
      ),
    );
  }
}
