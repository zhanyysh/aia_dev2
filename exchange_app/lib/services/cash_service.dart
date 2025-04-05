// lib/services/cash_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/cash_transaction.dart';

class CashService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Stream<List<CashTransaction>> getTransactions(DateTime startDate, DateTime endDate) {
    final user = _auth.currentUser;
    if (user == null) {
      print('CashService: Пользователь не аутентифицирован');
      throw Exception('User not authenticated');
    }

    print('CashService: Запрос транзакций для пользователя ${user.uid}');
    return _firestore
        .collection('users')
        .doc(user.uid)
        .collection('events')
        .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(startDate))
        .where('date', isLessThanOrEqualTo: Timestamp.fromDate(endDate))
        .orderBy('date', descending: true)
        .snapshots()
        .map((snapshot) {
      print('CashService: Получено ${snapshot.docs.length} документов');
      return snapshot.docs.map((doc) {
        return CashTransaction.fromFirestore(doc);
      }).toList();
    });
  }

  // Метод для сохранения итоговой статистики в kassa (оставляем без изменений)
  Future<void> saveSummaryStats({
    required DateTime startDate,
    required DateTime endDate,
    required double totalTurnover,
    required double totalProfit,
    required Map<String, double> buyAmounts,
    required Map<String, double> sellAmounts,
    required Map<String, int> buyCounts,
    required Map<String, int> sellCounts,
  }) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw Exception('Пользователь не авторизован');
    }

    await _firestore.collection('kassa').add({
      'userId': user.uid,
      'startDate': Timestamp.fromDate(startDate),
      'endDate': Timestamp.fromDate(endDate),
      'totalTurnover': totalTurnover,
      'totalProfit': totalProfit,
      'buyAmounts': buyAmounts,
      'sellAmounts': sellAmounts,
      'buyCounts': buyCounts,
      'sellCounts': sellCounts,
      'createdAt': Timestamp.now(),
    });
  }

  // Метод для чтения итоговой статистики из kassa (оставляем без изменений)
  Stream<List<Map<String, dynamic>>> getSummaryStats() {
    final user = _auth.currentUser;
    if (user == null) {
      return Stream.value([]);
    }

    return _firestore
        .collection('kassa')
        .where('userId', isEqualTo: user.uid)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => doc.data()).toList());
  }
}