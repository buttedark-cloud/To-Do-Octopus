import 'package:cloud_firestore/cloud_firestore.dart';

class CloudSyncService {
  CloudSyncService._();
  static final CloudSyncService instance = CloudSyncService._();

  final FirebaseFirestore _db = FirebaseFirestore.instance;

  DocumentReference<Map<String, dynamic>> _userDoc(String uid) =>
      _db.collection('users').doc(uid);

  Future<Map<String, dynamic>?> fetchOnce(String uid) async {
    final snapshot = await _userDoc(uid).get();
    return snapshot.data();
  }

  Stream<Map<String, dynamic>?> watch(String uid) {
    return _userDoc(uid).snapshots().map((snapshot) => snapshot.data());
  }

  Future<void> push(String uid, Map<String, dynamic> data) async {
    await _userDoc(
      uid,
    ).set({...data, 'updatedAt': FieldValue.serverTimestamp()});
  }

  /// Удаляет все данные пользователя из облака (при удалении аккаунта).
  Future<void> deleteUserData(String uid) async {
    await _userDoc(uid).delete();
  }
}
