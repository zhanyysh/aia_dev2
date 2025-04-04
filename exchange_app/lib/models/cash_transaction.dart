import 'package:cloud_firestore/cloud_firestore.dart';

class CashTransaction {
  final String id;
  final String type; // 'buy' или 'sell'
  final String currency;
  final double amount;
  final double total;
  final DateTime transactionDate;

  CashTransaction({
    required this.id,
    required this.type,
    required this.currency,
    required this.amount,
    required this.total,
    required this.transactionDate,
  });

  factory CashTransaction.fromFirestore(Map<String, dynamic> map) {
    return CashTransaction(
      id: map['id'] as String? ?? '',
      type: map['type'] as String? ?? '',
      currency: map['currency'] as String? ?? '',
      amount: (map['amount'] as num?)?.toDouble() ?? 0.0,
      total: (map['total'] as num?)?.toDouble() ?? 0.0,
      transactionDate: (map['date'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'id': id,
      'type': type,
      'currency': currency,
      'amount': amount,
      'total': total,
      'date': transactionDate, // Сохраняем как 'date', чтобы соответствовать структуре events
    };
  }
}