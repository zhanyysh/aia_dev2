// lib/models/cash_transaction.dart
import 'package:cloud_firestore/cloud_firestore.dart'; // Добавляем импорт

class CashTransaction {
  final String currency;
  final String type;
  final double amount;
  final double total;
  final DateTime timestamp;

  CashTransaction({
    required this.currency,
    required this.type,
    required this.amount,
    required this.total,
    required this.timestamp,
  });

  factory CashTransaction.fromFirestore(Map<String, dynamic> data) {
    return CashTransaction(
      currency: data['currency'] ?? '',
      type: data['type'] ?? '',
      amount: (data['amount'] as num?)?.toDouble() ?? 0.0,
      total: (data['total'] as num?)?.toDouble() ?? 0.0,
      timestamp: (data['date'] as Timestamp?)?.toDate() ?? DateTime.now(), // Теперь Timestamp доступен
    );
  }
}