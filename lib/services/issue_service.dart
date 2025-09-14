import 'package:cloud_firestore/cloud_firestore.dart';

class IssueService {

  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Stream<List<Map<String, dynamic>>> watchRequests(String warehouseId) {
    return _db
        .collection('requests')
        .where('toWarehouseId', isEqualTo: warehouseId)
        .snapshots()
        .map((s) => s.docs.map((d) => {
      'id': d.id,
      ...d.data(),
    }).toList());
  }

}
