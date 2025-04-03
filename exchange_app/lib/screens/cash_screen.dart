// lib/screens/cash_screen.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/cash_transaction.dart';
import '../services/cash_service.dart';
import '../services/auth_service.dart';
import '../widgets/app_drawer.dart';

class CashScreen extends StatefulWidget {
  const CashScreen({super.key});

  @override
  _CashScreenState createState() => _CashScreenState();
}

class _CashScreenState extends State<CashScreen> {
  final CashService _cashService = CashService();
  final AuthService _authService = AuthService();
  String _selectedPeriod = 'Сегодня'; // По умолчанию сегодня
  final List<String> _periodOptions = ['Сегодня', '3 дня', 'Неделя', 'Месяц', 'Кастомный период', 'За все время', 'Ручной выбор'];
  DateTime _startDate = DateTime.now().subtract(const Duration(days: 7));
  DateTime _endDate = DateTime.now();
  final TextEditingController _startDateController = TextEditingController();
  final TextEditingController _endDateController = TextEditingController();
  String _chartType = 'Количество операций';
  int _touchedIndex = -1;
  bool _isAuthenticated = false;

  @override
  void initState() {
    super.initState();
    _checkAuthenticationStatus();
  }

  Future<void> _checkAuthenticationStatus() async {
    User? user = _authService.getCurrentUser();
    print('Текущий пользователь: ${user?.uid}'); // Отладочный вывод
    setState(() {
      _isAuthenticated = user != null;
    });
  }

  // Метод для получения начальной и конечной даты в зависимости от выбранного периода
  Map<String, dynamic> _getDateRange() {
    final now = DateTime.now();
    DateTime startDate;
    DateTime endDate;

    if (_selectedPeriod == 'Ручной выбор') {
      // Если выбран "Ручной выбор", используем текущие значения _startDate и _endDate
      startDate = _startDate;
      endDate = _endDate;
      if (endDate.isBefore(startDate)) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Конечная дата не может быть раньше начальной')),
        );
        return {
          'start': now,
          'end': now,
        };
      }
    } else if (_selectedPeriod == 'Кастомный период' && _startDateController.text.isNotEmpty && _endDateController.text.isNotEmpty) {
      // Если выбран "Кастомный период", используем даты из контроллеров
      startDate = DateFormat('dd.MM.yyyy').parse(_startDateController.text);
      endDate = DateFormat('dd.MM.yyyy').parse(_endDateController.text);
      if (endDate.isBefore(startDate)) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Конечная дата не может быть раньше начальной')),
        );
        return {
          'start': now,
          'end': now,
        };
      }
      endDate = endDate.add(const Duration(days: 1)); // Включаем весь конечный день
    } else if (_selectedPeriod == 'За все время') {
      startDate = DateTime(2000); // Очень ранняя дата для "За все время"
      endDate = now;
    } else {
      switch (_selectedPeriod) {
        case 'Сегодня':
          startDate = DateTime(now.year, now.month, now.day); // Начало текущего дня
          endDate = now; // Текущее время
          break;
        case '3 дня':
          startDate = now.subtract(const Duration(days: 3)); // Последние 3 дня
          endDate = now;
          break;
        case 'Неделя':
          startDate = now.subtract(const Duration(days: 7)); // Последняя неделя
          endDate = now;
          break;
        case 'Месяц':
          // Предыдущий календарный месяц
          final previousMonth = DateTime(now.year, now.month - 1, 1); // 1-е число предыдущего месяца
          startDate = previousMonth;
          endDate = DateTime(now.year, now.month, 0); // Последний день предыдущего месяца
          break;
        default:
          startDate = now.subtract(const Duration(days: 30)); // На всякий случай, если что-то пойдёт не так
          endDate = now;
          break;
      }
    }

    print('Выбранный период: $_selectedPeriod, Диапазон: $startDate - $endDate'); // Отладочный вывод
    return {
      'start': startDate,
      'end': endDate,
    };
  }

  // Метод для выбора даты (для ручного выбора и кастомного периода)
  Future<void> _selectDate(BuildContext context, bool isStart) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: isStart ? _startDate : _endDate,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() {
        if (isStart) {
          _startDate = picked;
          if (_selectedPeriod == 'Кастомный период') {
            _startDateController.text = DateFormat('dd.MM.yyyy').format(picked);
          }
        } else {
          _endDate = picked;
          if (_selectedPeriod == 'Кастомный период') {
            _endDateController.text = DateFormat('dd.MM.yyyy').format(picked);
          }
        }
      });
    }
  }

  Map<String, dynamic> _calculateStats(List<CashTransaction> transactions) {
    Map<String, double> buyAmounts = {};
    Map<String, double> sellAmounts = {};
    Map<String, int> buyCounts = {};
    Map<String, int> sellCounts = {};
    double totalTurnover = 0;
    double totalProfit = 0;

    for (var tx in transactions) {
      totalTurnover += tx.total;
      if (tx.type == 'buy') {
        buyAmounts[tx.currency] = (buyAmounts[tx.currency] ?? 0) + tx.amount;
        buyCounts[tx.currency] = (buyCounts[tx.currency] ?? 0) + 1;
      } else if (tx.type == 'sell') {
        sellAmounts[tx.currency] = (sellAmounts[tx.currency] ?? 0) + tx.amount;
        sellCounts[tx.currency] = (sellCounts[tx.currency] ?? 0) + 1;
        totalProfit += tx.total;
      }
    }

    return {
      'buyAmounts': buyAmounts,
      'sellAmounts': sellAmounts,
      'buyCounts': buyCounts,
      'sellCounts': sellCounts,
      'totalTurnover': totalTurnover,
      'totalProfit': totalProfit,
    };
  }

  @override
  void dispose() {
    _startDateController.dispose();
    _endDateController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Отчёт по кассе'),
        backgroundColor: Colors.blueAccent,
      ),
      drawer: AppDrawer(currentRoute: 'cash', authService: _authService),
      body: _isAuthenticated
          ? Column(
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
                                if (_selectedPeriod != 'Кастомный период' && _selectedPeriod != 'Ручной выбор') {
                                  _startDateController.clear();
                                  _endDateController.clear();
                                }
                              });
                            },
                          ),
                        ],
                      ),
                      // Поля для кастомного периода или ручного выбора
                      if (_selectedPeriod == 'Кастомный период' || _selectedPeriod == 'Ручной выбор') ...[
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Начальная дата:'),
                                TextButton(
                                  onPressed: () => _selectDate(context, true),
                                  child: Text(DateFormat('dd.MM.yyyy').format(_startDate)),
                                ),
                              ],
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Конечная дата:'),
                                TextButton(
                                  onPressed: () => _selectDate(context, false),
                                  child: Text(DateFormat('dd.MM.yyyy').format(_endDate)),
                                ),
                              ],
                            ),
                          ],
                        ),
                        if (_selectedPeriod == 'Кастомный период') ...[
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
                    ],
                  ),
                ),
                // Основной контент
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(16.0),
                    child: StreamBuilder<List<CashTransaction>>(
                      stream: () {
                        final dateRange = _getDateRange();
                        return _cashService.getTransactions(dateRange['start'], dateRange['end']);
                      }(),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState == ConnectionState.waiting) {
                          return const Center(child: CircularProgressIndicator());
                        }
                        if (snapshot.hasError) {
                          return Center(child: Text('Ошибка: ${snapshot.error}'));
                        }
                        if (!snapshot.hasData || snapshot.data!.isEmpty) {
                          return const Center(child: Text('Нет данных за этот период'));
                        }

                        final transactions = snapshot.data!;
                        final stats = _calculateStats(transactions);

                        final buyAmounts = stats['buyAmounts'] as Map<String, double>;
                        final sellAmounts = stats['sellAmounts'] as Map<String, double>;
                        final buyCounts = stats['buyCounts'] as Map<String, int>;
                        final sellCounts = stats['sellCounts'] as Map<String, int>;
                        final totalTurnover = stats['totalTurnover'] as double;
                        final totalProfit = stats['totalProfit'] as double;

                        List<String> currencies = buyAmounts.keys
                            .followedBy(sellAmounts.keys)
                            .toSet()
                            .toList();
                        List<DataRow> rows = currencies.map((currency) {
                          double buyAvg = (buyCounts[currency] ?? 0) > 0
                              ? (buyAmounts[currency] ?? 0) / buyCounts[currency]!
                              : 0;
                          double sellAvg = (sellCounts[currency] ?? 0) > 0
                              ? (sellAmounts[currency] ?? 0) / sellCounts[currency]!
                              : 0;
                          double profit = (sellAmounts[currency] ?? 0) -
                              (buyAmounts[currency] ?? 0);

                          return DataRow(cells: [
                            DataCell(Text(currency)),
                            DataCell(Text(buyAmounts[currency]?.toStringAsFixed(2) ?? '0')),
                            DataCell(Text(sellAmounts[currency]?.toStringAsFixed(2) ?? '0')),
                            DataCell(Text((buyCounts[currency] ?? 0).toString())),
                            DataCell(Text((sellCounts[currency] ?? 0).toString())),
                            DataCell(Text(buyAvg.toStringAsFixed(2))),
                            DataCell(Text(sellAvg.toStringAsFixed(2))),
                            DataCell(Text(profit.toStringAsFixed(2))),
                          ]);
                        }).toList();

                        List<PieChartSectionData> pieSections = [];
                        if (_chartType == 'Количество операций') {
                          pieSections = currencies.asMap().entries.map((entry) {
                            int idx = entry.key;
                            String currency = entry.value;
                            double value = (buyCounts[currency] ?? 0) + (sellCounts[currency] ?? 0).toDouble();
                            return PieChartSectionData(
                              color: Colors.primaries[idx % Colors.primaries.length],
                              value: value,
                              title: '$currency\n$value',
                              radius: _touchedIndex == idx ? 60 : 50,
                              titleStyle: const TextStyle(fontSize: 12, color: Colors.white),
                            );
                          }).toList();
                        } else if (_chartType == 'Средние показатели') {
                          pieSections = currencies.asMap().entries.map((entry) {
                            int idx = entry.key;
                            String currency = entry.value;
                            double buyAvg = (buyCounts[currency] ?? 0) > 0
                                ? (buyAmounts[currency] ?? 0) / buyCounts[currency]!
                                : 0;
                            double sellAvg = (sellCounts[currency] ?? 0) > 0
                                ? (sellAmounts[currency] ?? 0) / sellCounts[currency]!
                                : 0;
                            double avg = (buyAvg + sellAvg) / 2;
                            return PieChartSectionData(
                              color: Colors.primaries[idx % Colors.primaries.length],
                              value: avg,
                              title: '$currency\n${avg.toStringAsFixed(2)}',
                              radius: _touchedIndex == idx ? 60 : 50,
                              titleStyle: const TextStyle(fontSize: 12, color: Colors.white),
                            );
                          }).toList();
                        } else if (_chartType == 'Прибыль') {
                          pieSections = currencies.asMap().entries.map((entry) {
                            int idx = entry.key;
                            String currency = entry.value;
                            double profit = (sellAmounts[currency] ?? 0) -
                                (buyAmounts[currency] ?? 0);
                            return PieChartSectionData(
                              color: Colors.primaries[idx % Colors.primaries.length],
                              value: profit > 0 ? profit : 0,
                              title: '$currency\n${profit.toStringAsFixed(2)}',
                              radius: _touchedIndex == idx ? 60 : 50,
                              titleStyle: const TextStyle(fontSize: 12, color: Colors.white),
                            );
                          }).toList();
                        }

                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Данные по операциям:', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                            SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: DataTable(
                                columns: const [
                                  DataColumn(label: Text('Валюта')),
                                  DataColumn(label: Text('Сумма покупок')),
                                  DataColumn(label: Text('Сумма продаж')),
                                  DataColumn(label: Text('Кол-во покупок')),
                                  DataColumn(label: Text('Кол-во продаж')),
                                  DataColumn(label: Text('Средняя покупка')),
                                  DataColumn(label: Text('Средняя продажа')),
                                  DataColumn(label: Text('Прибыль')),
                                ],
                                rows: rows,
                              ),
                            ),
                            const SizedBox(height: 20),
                            const Text('Тип графика:', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                            DropdownButton<String>(
                              value: _chartType,
                              items: const [
                                DropdownMenuItem(value: 'Количество операций', child: Text('Количество операций')),
                                DropdownMenuItem(value: 'Средние показатели', child: Text('Средние показатели')),
                                DropdownMenuItem(value: 'Прибыль', child: Text('Прибыль')),
                              ],
                              onChanged: (value) {
                                setState(() {
                                  _chartType = value!;
                                  _touchedIndex = -1;
                                });
                              },
                            ),
                            const SizedBox(height: 20),
                            const Text('Диаграмма:', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                            SizedBox(
                              height: 200,
                              child: PieChart(
                                PieChartData(
                                  sections: pieSections,
                                  sectionsSpace: 2,
                                  centerSpaceRadius: 40,
                                  pieTouchData: PieTouchData(
                                    touchCallback: (FlTouchEvent event, pieTouchResponse) {
                                      setState(() {
                                        if (!event.isInterestedForInteractions ||
                                            pieTouchResponse == null ||
                                            pieTouchResponse.touchedSection == null) {
                                          _touchedIndex = -1;
                                          return;
                                        }
                                        _touchedIndex = pieTouchResponse.touchedSection!.touchedSectionIndex;
                                      });
                                    },
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 20),
                            const Text('Итоги:', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                            Text('Общий оборот: ${totalTurnover.toStringAsFixed(2)}'),
                            Text('Общая прибыль: ${totalProfit.toStringAsFixed(2)}'),
                          ],
                        );
                      },
                    ),
                  ),
                ),
              ],
            )
          : const Center(
              child: Text(
                'Пожалуйста, войдите в систему, чтобы просмотреть этот экран.',
                style: TextStyle(fontSize: 18, color: Colors.red),
                textAlign: TextAlign.center,
              ),
            ),
    );
  }
}