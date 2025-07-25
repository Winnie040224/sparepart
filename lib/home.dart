import 'package:flutter/material.dart';
import 'package:spacepart/itemDetails.dart';

import 'addStockPage.dart';
import 'createNewItem.dart';

class Item {
  final int id;
  final String name;

  Item(this.id, this.name);
}

class HomePage extends StatelessWidget {
  final List<Item> catalog = [
    Item(001, 'Oil Filter'),
    Item(002, 'Air Filter'),
    Item(003, 'Brake Pad'),
    Item(004, 'Spark Plug'),
    Item(005, 'Fuel Pump'),
    Item(006, 'Alternator'),
    Item(007, 'Radiator Hose'),
    Item(008, 'Timing Belt'),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Staff Dashboard"),
        centerTitle: true,
      ),

      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                GestureDetector(
                  onTap: () {},
                  child: Column(
                    children: [
                      Container(
                        width: 150,
                        height: 80,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.black12),
                        ),
                        child: Icon(Icons.list, size: 30),
                      ),
                      SizedBox(height: 5),
                      Text("Order Lists"),
                    ],
                  ),
                ),
                GestureDetector(
                  onTap: () {},
                  child: Column(
                    children: [
                      Container(
                        width: 150,
                        height: 80,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.black12),
                        ),
                        child: Icon(Icons.warning, size: 30),
                      ),
                      SizedBox(height: 5),
                      Text("Warning"),
                    ],
                  ),
                ),
              ],
            ),
            SizedBox(height: 20),

            Text("Stock :"),
            Expanded(
              child: ListView.builder(
                itemCount: catalog.length,
                itemBuilder: (context, index) {
                  final item = catalog[index];
                  return Card(
                    margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: ListTile(
                      title: Text(item.name),
                      subtitle: Text("ID: ${item.id}"),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => ItemDetailPage(item: item)),
                        );
                      },
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),

      floatingActionButton: FloatingActionButton(
        onPressed: () {
          showModalBottomSheet(
            context: context,
            builder: (context) => Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: Icon(Icons.add_box),
                  title: Text("Add New Stock"),
                  onTap: () => Navigator.push(context, MaterialPageRoute(
                    builder: (_) => AddStockPage(),
                ))
                ),
                ListTile(
                  leading: Icon(Icons.new_releases),
                  title: Text("Create New Item"),
                  onTap: () => Navigator.push(context,MaterialPageRoute(
                  builder: (_) => CreateNewItemPage()),),)
              ],
            ),
          );

        },
        child: Icon(Icons.add),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,

      bottomNavigationBar: BottomAppBar(
        shape: CircularNotchedRectangle(),
        notchMargin: 8,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            IconButton(icon: Icon(Icons.home), onPressed: () {}),
            IconButton(icon: Icon(Icons.contact_page), onPressed: () {}),
            SizedBox(width: 40),
            IconButton(icon: Icon(Icons.settings), onPressed: () {}),
            IconButton(icon: Icon(Icons.person), onPressed: () {}),
          ],
        ),
      ),
    );
  }
}
