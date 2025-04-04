import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:exchange_app/services/auth_service.dart';
import 'package:intl/intl.dart'; // Для форматирования даты

class EventsScreen extends StatefulWidget {
  const EventsScreen({super.key});

  @override
  State<EventsScreen> createState() => _EventsScreenState();
}

class _EventsScreenState extends State<EventsScreen> {
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _currencyController = TextEditingController();
  final AuthService _authService = AuthService();

  // Переменные для выбора периода
  String _selectedPeriod = 'Месяц'; // По умолчанию месяц
  final List<String> _periodOptions = ['3 дня', 'Неделя', 'Месяц', 'Кастомный период', 'За все время'];

  // Переменные для кастомного периода
  DateTime? _startDate;
  DateTime? _endDate;
  final TextEditingController _startDateController = TextEditingController();
  final TextEditingController _endDateController = TextEditingController();

  Future<bool> _isSuperAdmin() async {
    final user = _authService.getCurrentUser()!;
    final userDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
    return userDoc.data()?['isSuperAdmin'] ?? false;
  }

  Future<void> _addEvent() async {
    final user = FirebaseAuth.instance.currentUser!;
    final title = _titleController.text.trim();
    final description = _descriptionController.text.trim();
    final currency = _currencyController.text.trim();

    if (title.isEmpty || description.isEmpty || currency.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Заполните все поля')),
      );
      return;
    }

    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('events')
          .add({
        'title': title,
        'description': description,
        'currency': currency,
        'date': Timestamp.now(),
        'type': 'custom',
      });
      _titleController.clear();
      _descriptionController.clear();
      _currencyController.clear();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Событие добавлено')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ошибка: $e')),
      );
    }
  }

  // Метод для получения начальной и конечной даты в зависимости от выбранного периода
  Map<String, dynamic> _getDateRange() {
    final now = DateTime.now();
    DateTime startDate;
    DateTime endDate = now;

    if (_selectedPeriod == 'Кастомный период' && _startDate != null && _endDate != null) {
      if (_endDate!.isBefore(_startDate!)) {
        // Если конечная дата раньше начальной, показываем ошибку и возвращаем пустой диапазон
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Конечная дата не может быть раньше начальной')),
        );
        return {
          'start': Timestamp.fromDate(now),
          'end': Timestamp.fromDate(now),
        };
      }
      startDate = _startDate!;
      endDate = _endDate!.add(const Duration(days: 1)); // Добавляем 1 день, чтобы включить события в течение конечного дня
    } else if (_selectedPeriod == 'За все время') {
      // Для "За все время" устанавливаем очень раннюю начальную дату
      startDate = DateTime(2000);
      endDate = now;
    } else {
      switch (_selectedPeriod) {
        case '3 дня':
          startDate = now.subtract(const Duration(days: 3));
          break;
        case 'Неделя':
          startDate = now.subtract(const Duration(days: 7));
          break;
        case 'Месяц':
        default:
          startDate = now.subtract(const Duration(days: 30));
          break;
      }
    }

    return {
      'start': Timestamp.fromDate(startDate),
      'end': Timestamp.fromDate(endDate),
    };
  }

  // Метод для выбора даты
  Future<void> _selectDate(BuildContext context, bool isStartDate) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: isStartDate ? (_startDate ?? DateTime.now()) : (_endDate ?? DateTime.now()),
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() {
        if (isStartDate) {
          _startDate = picked;
          _startDateController.text = DateFormat('dd.MM.yyyy').format(picked);
        } else {
          _endDate = picked;
          _endDateController.text = DateFormat('dd.MM.yyyy').format(picked);
        }
      });
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _currencyController.dispose();
    _startDateController.dispose();
    _endDateController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser!;
    return Scaffold(
      appBar: AppBar(
        title: const Text('События'),
        backgroundColor: Colors.blueAccent,
        elevation: 0,
      ),
      body: Column(
        children: [
          // Выбор периода
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Период:',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    DropdownButton<String>(
                      value: _selectedPeriod,
                      items: _periodOptions.map((period) {
                        return DropdownMenuItem<String>(
                          value: period,
                          child: Text(period),
                        );
                      }).toList(),
                      onChanged: (value) {
                        setState(() {
                          _selectedPeriod = value!;
                          if (_selectedPeriod != 'Кастомный период') {
                            _startDate = null;
                            _endDate = null;
                            _startDateController.clear();
                            _endDateController.clear();
                          }
                        });
                      },
                    ),
                  ],
                ),
                // Поля для кастомного периода
                if (_selectedPeriod == 'Кастомный период') ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _startDateController,
                          readOnly: true,
                          decoration: const InputDecoration(
                            labelText: 'Начальная дата',
                            border: OutlineInputBorder(),
                          ),
                          onTap: () => _selectDate(context, true),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: TextField(
                          controller: _endDateController,
                          readOnly: true,
                          decoration: const InputDecoration(
                            labelText: 'Конечная дата',
                            border: OutlineInputBorder(),
                          ),
                          onTap: () => _selectDate(context, false),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          // Форма для супер-админа
          FutureBuilder<bool>(
            future: _isSuperAdmin(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const SizedBox.shrink();
              }
              if (snapshot.hasData && snapshot.data == true) {
                return Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      TextField(
                        controller: _titleController,
                        decoration: const InputDecoration(
                          labelText: 'Название события',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _descriptionController,
                        decoration: const InputDecoration(
                          labelText: 'Описание',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _currencyController,
                        decoration: const InputDecoration(
                          labelText: 'Валюта (например, USD)',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _addEvent,
                        child: const Text('Добавить событие'),
                      ),
                    ],
                  ),
                );
              }
              return const SizedBox.shrink();
            },
          ),
          // Таблица с отфильтрованными событиями и статистикой под ней
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: () {
                final dateRange = _getDateRange();
                if (_selectedPeriod == 'Кастомный период' && _startDate != null && _endDate != null) {
                  return FirebaseFirestore.instance
                      .collection('users')
                      .doc(user.uid)
                      .collection('events')
                      .where('date', isGreaterThanOrEqualTo: dateRange['start'])
                      .where('date', isLessThan: dateRange['end'])
                      .orderBy('date', descending: true)
                      .snapshots();
                } else if (_selectedPeriod != 'Кастомный период') {
                  if (_selectedPeriod == 'За все время') {
                    return FirebaseFirestore.instance
                        .collection('users')
                        .doc(user.uid)
                        .collection('events')
                        .orderBy('date', descending: true)
                        .snapshots();
                  }
                  return FirebaseFirestore.instance
                      .collection('users')
                      .doc(user.uid)
                      .collection('events')
                      .where('date', isGreaterThanOrEqualTo: dateRange['start'])
                      .orderBy('date', descending: true)
                      .snapshots();
                } else {
                  return FirebaseFirestore.instance
                      .collection('users')
                      .doc(user.uid)
                      .collection('events')
                      .orderBy('date', descending: true)
                      .snapshots();
                }
              }(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(child: Text('Ошибка: ${snapshot.error}'));
                }
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const Center(child: Text('Нет доступных событий за выбранный период'));
                }

                final events = snapshot.data!.docs;

                // Подсчитываем среднее количество покупок и продаж
                double totalBuyAmount = 0;
                double totalSellAmount = 0;
                int buyCount = 0;
                int sellCount = 0;

                for (var eventDoc in events) {
                  final event = eventDoc.data() as Map<String, dynamic>;
                  final type = event['type'] ?? 'custom';
                  final amount = (event['amount'] as num?)?.toDouble() ?? 0.0;

                  if (type == 'buy') {
                    totalBuyAmount += amount;
                    buyCount++;
                  } else if (type == 'sell') {
                    totalSellAmount += amount;
                    sellCount++;
                  }
                }

                // Вычисляем среднее количество покупок и продаж
                final avgBuy = buyCount > 0 ? totalBuyAmount / buyCount : 0.0;
                final avgSell = sellCount > 0 ? totalSellAmount / sellCount : 0.0;

                return Column(
                  children: [
                    // Таблица
                    Expanded(
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: DataTable(
                          columns: const [
                            DataColumn(label: Text('Тип')),
                            DataColumn(label: Text('Валюта')),
                            DataColumn(label: Text('Кол-во')),
                            DataColumn(label: Text('Курс')),
                            DataColumn(label: Text('Дата')),
                            DataColumn(label: Text('Итого')),
                          ],
                          rows: events.map((eventDoc) {
                            final event = eventDoc.data() as Map<String, dynamic>;
                            final type = event['type'] ?? 'custom';
                            final currency = event['currency'] ?? '';
                            final amount = event['amount']?.toString() ?? '0';
                            final rate = event['rate']?.toString() ?? '0';
                            final total = event['total']?.toString() ?? '0';
                            final date = (event['date'] as Timestamp?)?.toDate();
                            final formattedDate = date != null
                                ? DateFormat('dd.MM.yyyy').format(date)
                                : '';

                            return DataRow(cells: [
                              DataCell(Text(type == 'sell'
                                  ? 'Продажа'
                                  : type == 'buy'
                                      ? 'Покупка'
                                      : 'Кастом')),
                              DataCell(Text(currency)),
                              DataCell(Text(amount)),
                              DataCell(Text(rate)),
                              DataCell(Text(formattedDate)),
                              DataCell(Text(total)),
                            ]);
                          }).toList(),
                        ),
                      ),
                    ),
                    // Статистика под таблицей
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Среднее кол-во продаж: ${avgSell.toStringAsFixed(2)}',
                            style: const TextStyle(fontSize: 16),
                          ),
                          Text(
                            'Среднее кол-во покупок: ${avgBuy.toStringAsFixed(2)}',
                            style: const TextStyle(fontSize: 16),
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}