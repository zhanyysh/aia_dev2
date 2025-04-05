import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart'; // Для форматирования даты

class EventsScreen extends StatefulWidget {
  const EventsScreen({super.key});

  @override
  State<EventsScreen> createState() => _EventsScreenState();
}

class _EventsScreenState extends State<EventsScreen> {
  // Переменные для выбора периода
  String _selectedPeriod = 'За сегодня';
  final List<String> _periodOptions = [
    'За сегодня',
    'За 3 дня',
    'За неделю',
    'За месяц',
    'За все время',
    'Кастомный период', // Перенесён в конец
  ];

  // Переменные для кастомного периода
  DateTime? _startDate;
  DateTime? _endDate;
  final TextEditingController _startDateController = TextEditingController();
  final TextEditingController _endDateController = TextEditingController();

  // Переменная для выбора дня для таблицы прибыли
  DateTime _selectedProfitDate = DateTime.now(); // По умолчанию текущий день
  final TextEditingController _profitDateController = TextEditingController();

  // Инициализация контроллера даты прибыли
  @override
  void initState() {
    super.initState();
    _profitDateController.text = DateFormat('dd.MM.yyyy').format(_selectedProfitDate);
  }

  // Метод для получения начальной и конечной даты в зависимости от выбранного периода
  Map<String, dynamic> _getDateRange() {
    final now = DateTime.now();
    DateTime startDate;
    DateTime endDate = now;

    if (_selectedPeriod == 'Кастомный период' && _startDate != null && _endDate != null) {
      if (_endDate!.isBefore(_startDate!)) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Конечная дата не может быть раньше начальной')),
        );
        return {
          'start': Timestamp.fromDate(now),
          'end': Timestamp.fromDate(now),
        };
      }
      startDate = _startDate!;
      endDate = _endDate!.add(const Duration(days: 1));
    } else if (_selectedPeriod == 'За все время') {
      startDate = DateTime(2000);
      endDate = now;
    } else {
      switch (_selectedPeriod) {
        case 'За сегодня':
          startDate = DateTime(now.year, now.month, now.day);
          endDate = startDate.add(const Duration(days: 1));
          break;
        case 'За 3 дня':
          startDate = now.subtract(const Duration(days: 3));
          break;
        case 'За неделю':
          startDate = now.subtract(const Duration(days: 7));
          break;
        case 'За месяц':
          startDate = now.subtract(const Duration(days: 30));
          break;
        default:
          startDate = now.subtract(const Duration(days: 30)); // По умолчанию месяц
          break;
      }
    }

    return {
      'start': Timestamp.fromDate(startDate),
      'end': Timestamp.fromDate(endDate),
    };
  }

  // Метод для выбора даты для таблицы транзакций
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

  // Метод для выбора даты для таблицы прибыли
  Future<void> _selectProfitDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedProfitDate,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() {
        _selectedProfitDate = picked;
        _profitDateController.text = DateFormat('dd.MM.yyyy').format(picked);
      });
    }
  }

  @override
  void dispose() {
    _startDateController.dispose();
    _endDateController.dispose();
    _profitDateController.dispose();
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
      body: SingleChildScrollView(
        child: Column(
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
            // Таблица транзакций (с учётом выбранного периода)
            SizedBox(
              height: MediaQuery.of(context).size.height * 0.5, // Ограничиваем высоту таблицы транзакций
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
                  } else if (_selectedPeriod == 'За сегодня') {
                    return FirebaseFirestore.instance
                        .collection('users')
                        .doc(user.uid)
                        .collection('events')
                        .where('date', isGreaterThanOrEqualTo: dateRange['start'])
                        .where('date', isLessThan: dateRange['end'])
                        .orderBy('date', descending: true)
                        .snapshots();
                  } else if (_selectedPeriod == 'За все время') {
                    return FirebaseFirestore.instance
                        .collection('users')
                        .doc(user.uid)
                        .collection('events')
                        .orderBy('date', descending: true)
                        .snapshots();
                  } else {
                    return FirebaseFirestore.instance
                        .collection('users')
                        .doc(user.uid)
                        .collection('events')
                        .where('date', isGreaterThanOrEqualTo: dateRange['start'])
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

                  return SingleChildScrollView(
                    scrollDirection: Axis.vertical, // Вертикальная прокрутка для таблицы транзакций
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: DataTable(
                        columns: const [
                          DataColumn(label: Text('Тип')),
                          DataColumn(label: Text('Валюта')),
                          DataColumn(label: Text('Кол-во')),
                          DataColumn(label: Text('Курс')),
                          DataColumn(label: Text('Дата')),
                        ],
                        rows: events.map((eventDoc) {
                          final event = eventDoc.data() as Map<String, dynamic>;
                          final type = event['type'] ?? 'custom';
                          final currency = event['currency'] ?? '';
                          final amount = event['amount']?.toString() ?? '0';
                          final rate = event['rate']?.toString() ?? '0';
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
                          ]);
                        }).toList(),
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 16), // Отступ между таблицами
            // Выбор даты для таблицы прибыли
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Прибыль за день:',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  SizedBox(
                    width: 150,
                    child: TextField(
                      controller: _profitDateController,
                      readOnly: true,
                      decoration: const InputDecoration(
                        labelText: 'Выберите день',
                        border: OutlineInputBorder(),
                      ),
                      onTap: () => _selectProfitDate(context),
                    ),
                  ),
                ],
              ),
            ),
            // Таблица "Прибыль с каждой валюты" (за выбранный день)
            StreamBuilder<QuerySnapshot>(
              stream: () {
                // Определяем начало и конец выбранного дня
                final startOfDay = DateTime(
                  _selectedProfitDate.year,
                  _selectedProfitDate.month,
                  _selectedProfitDate.day,
                );
                final endOfDay = startOfDay.add(const Duration(days: 1));

                return FirebaseFirestore.instance
                    .collection('users')
                    .doc(user.uid)
                    .collection('events')
                    .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
                    .where('date', isLessThan: Timestamp.fromDate(endOfDay))
                    .snapshots();
              }(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(child: Text('Ошибка: ${snapshot.error}'));
                }
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const Center(child: Text('Нет данных для отображения прибыли за выбранный день'));
                }

                final events = snapshot.data!.docs;

                // Группировка транзакций по валютам (за выбранный день)
                Map<String, Map<String, dynamic>> currencyProfitStats = {};

                for (var eventDoc in events) {
                  final event = eventDoc.data() as Map<String, dynamic>;
                  final type = event['type'] ?? 'custom';
                  final currency = event['currency'] ?? 'Unknown';
                  final amount = (event['amount'] as num?)?.toDouble() ?? 0.0;
                  final rate = (event['rate'] as num?)?.toDouble() ?? 0.0;

                  // Инициализируем статистику для валюты, если её ещё нет
                  if (!currencyProfitStats.containsKey(currency)) {
                    currencyProfitStats[currency] = {
                      'totalBuyAmount': 0.0, // Общее количество покупок
                      'totalBuyRate': 0.0, // Сумма курсов покупок
                      'buyCount': 0, // Количество транзакций покупок
                      'totalSellAmount': 0.0, // Общее количество продаж
                      'totalSellRate': 0.0, // Сумма курсов продаж
                      'sellCount': 0, // Количество транзакций продаж
                    };
                  }

                  // Обновляем статистику
                  if (type == 'buy') {
                    currencyProfitStats[currency]!['totalBuyAmount'] += amount;
                    currencyProfitStats[currency]!['totalBuyRate'] += rate;
                    currencyProfitStats[currency]!['buyCount']++;
                  } else if (type == 'sell') {
                    currencyProfitStats[currency]!['totalSellAmount'] += amount;
                    currencyProfitStats[currency]!['totalSellRate'] += rate;
                    currencyProfitStats[currency]!['sellCount']++;
                  }
                }

                // Формируем список для таблицы "Прибыль с каждой валюты"
                List<Map<String, dynamic>> profitStatsList = [];
                currencyProfitStats.forEach((currency, stats) {
                  final buyCount = stats['buyCount'];
                  final sellCount = stats['sellCount'];

                  // Средний курс покупки
                  final avgBuyRate = buyCount > 0 ? stats['totalBuyRate'] / buyCount : 0.0;
                  // Средний курс продажи
                  final avgSellRate = sellCount > 0 ? stats['totalSellRate'] / sellCount : 0.0;

                  // Средняя покупка = (Общее кол-во покупок * средний курс покупки) / Общее кол-во транзакций покупок
                  final totalBuyAmount = stats['totalBuyAmount'];
                  final avgBuy = buyCount > 0 ? (totalBuyAmount * avgBuyRate) / buyCount : 0.0;

                  // Средняя продажа = (Общее кол-во продаж * средний курс продажи) / Общее кол-во транзакций продаж
                  final totalSellAmount = stats['totalSellAmount'];
                  final avgSell = sellCount > 0 ? (totalSellAmount * avgSellRate) / sellCount : 0.0;

                  // Прибыль = Общее кол-во транзакций продаж * (средняя продажа - средняя покупка)
                  final profit = sellCount * (avgSell - avgBuy);

                  profitStatsList.add({
                    'currency': currency,
                    'avgSellRate': avgSellRate,
                    'sellCount': sellCount,
                    'profit': profit,
                  });
                });

                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Прибыль с каждой валюты за ${_profitDateController.text}:',
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      if (profitStatsList.isEmpty)
                        const Text(
                          'Нет данных для отображения',
                          style: TextStyle(fontSize: 16),
                        )
                      else
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: DataTable(
                            columns: const [
                              DataColumn(label: Text('Валюта')),
                              DataColumn(label: Text('Курс продажи')),
                              DataColumn(label: Text('Кол-во транзакций продаж')),
                              DataColumn(label: Text('Прибыль')),
                            ],
                            rows: profitStatsList.map((stat) {
                              return DataRow(cells: [
                                DataCell(Text(stat['currency'])),
                                DataCell(Text(stat['avgSellRate'].toStringAsFixed(2))),
                                DataCell(Text(stat['sellCount'].toString())),
                                DataCell(Text(stat['profit'].toStringAsFixed(2))),
                              ]);
                            }).toList(),
                          ),
                        ),
                    ],
                  ),
                );
              },
            ),
            const SizedBox(height: 16), // Дополнительный отступ внизу
          ],
        ),
      ),
    );
  }
}