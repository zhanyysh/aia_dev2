import 'package:cloud_firestore/cloud_firestore.dart';

class CashTransaction {
  final String id;
  final String type;
  final double amount;
  final double total;
  final double rate;
  final String currency;
  final DateTime transactionDate;
  final String userId;

  CashTransaction({
    required this.id,
    required this.type,
    required this.amount,
    required this.total,
    required this.rate,
    required this.currency,
    required this.transactionDate,
    required this.userId,
  });

  factory CashTransaction.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return CashTransaction(
      id: doc.id,
      type: data['type'] ?? '',
      amount: (data['amount'] ?? 0).toDouble(),
      total: (data['total'] ?? 0).toDouble(),
      rate: (data['rate'] ?? 0).toDouble(),
      currency: data['currency'] ?? '',
      // Проверяем, есть ли transactionDate, и если нет, используем DateTime.now()
      transactionDate: data['transactionDate'] != null
          ? (data['transactionDate'] as Timestamp).toDate()
          : DateTime.now(),
      userId: data['userId'] ?? '',
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'type': type,
      'amount': amount,
      'total': total,
      'rate': rate,
      'currency': currency,
      'transactionDate': Timestamp.fromDate(transactionDate),
      'userId': userId,
    };
  }
}