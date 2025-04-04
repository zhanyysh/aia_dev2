import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/cash_transaction.dart';

class CashService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Stream<List<CashTransaction>> getTransactions(DateTime startDate, DateTime endDate) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      print('Пользователь не авторизован');
      return const Stream.empty(); // Возвращаем пустой поток, если пользователь не авторизован
    }

    print('Запрос транзакций для пользователя ${user.uid} с $startDate по $endDate');
    return _firestore
        .collection('users')
        .doc(user.uid)
        .collection('events')
        .where('date', isGreaterThanOrEqualTo: startDate)
        .where('date', isLessThanOrEqualTo: endDate)
        .snapshots()
        .map((snapshot) {
          print('Получено документов: ${snapshot.docs.length}');
          return snapshot.docs.map((doc) {
            print('Документ: ${doc.data()}');
            // Добавляем ID документа в данные
            final data = doc.data();
            data['id'] = doc.id; // Добавляем ID документа в данные
            return CashTransaction.fromFirestore(data);
          }).toList();
        });
  }

  Future<void> addTransaction(CashTransaction transaction) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw Exception('Пользователь не авторизован');
    }

    await _firestore
        .collection('users')
        .doc(user.uid)
        .collection('events')
        .doc(transaction.id)
        .set(transaction.toFirestore());
  }
}