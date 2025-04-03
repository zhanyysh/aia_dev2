// lib/services/cash_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/cash_transaction.dart';

class CashService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Stream<List<CashTransaction>> getTransactions(DateTime startDate, DateTime endDate) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const Stream.empty(); // Если пользователь не авторизован, возвращаем пустой поток
    }

    return _firestore
        .collection('users')
        .doc(user.uid)
        .collection('events')
        .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(startDate))
        .where('date', isLessThanOrEqualTo: Timestamp.fromDate(endDate))
        .orderBy('date', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => CashTransaction.fromFirestore(doc.data()))
            .toList());
  }
}