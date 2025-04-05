import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/cash_transaction.dart';
import '../services/cash_service.dart';
import '../services/auth_service.dart';

// Виджет индикатора для легенды
class Indicator extends StatelessWidget {
  final Color color;
  final String text;
  final bool isSquare;
  final double size;
  final Color textColor;

  const Indicator({
    Key? key,
    required this.color,
    required this.text,
    this.isSquare = true,
    this.size = 16,
    this.textColor = const Color(0xff505050),
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: isSquare ? BoxShape.rectangle : BoxShape.circle,
            color: color,
          ),
        ),
        const SizedBox(width: 4),
        Text(
          text,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: textColor,
          ),
        ),
      ],
    );
  }
}

class CashScreen extends StatefulWidget {
  const CashScreen({super.key});

  @override
  _CashScreenState createState() => _CashScreenState();
}

class _CashScreenState extends State<CashScreen> {
  final CashService _cashService = CashService();
  final AuthService _authService = AuthService();
  String _selectedPeriod = '3 дня';
  final List<String> _periodOptions = [
    'Сегодня',
    '3 дня',
    'Неделя',
    'Месяц',
    'Кастомный период',
    'За все время',
  ];
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
    print('Текущий пользователь: ${user?.uid}');
    setState(() {
      _isAuthenticated = user != null;
    });
  }

  Map<String, dynamic> _getDateRange() {
    final now = DateTime.now();
    DateTime startDate;
    DateTime endDate;

    if (_selectedPeriod == 'Кастомный период' &&
        _startDateController.text.isNotEmpty &&
        _endDateController.text.isNotEmpty) {
      startDate = DateFormat('dd.MM.yyyy').parse(_startDateController.text);
      endDate = DateFormat('dd.MM.yyyy').parse(_endDateController.text);
      if (endDate.isBefore(startDate)) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Конечная дата не может быть раньше начальной')),
        );
        return {
          'start': Timestamp.fromDate(now),
          'end': Timestamp.fromDate(now),
        };
      }
      endDate = DateTime(endDate.year, endDate.month, endDate.day, 23, 59, 59);
    } else if (_selectedPeriod == 'За все время') {
      startDate = DateTime(2000);
      endDate = now;
    } else {
      switch (_selectedPeriod) {
        case 'Сегодня':
          startDate = DateTime(now.year, now.month, now.day);
          endDate = DateTime(now.year, now.month, now.day, 23, 59, 59);
          break;
        case '3 дня':
          startDate = now.subtract(const Duration(days: 3));
          endDate = DateTime(now.year, now.month, now.day, 23, 59, 59);
          break;
        case 'Неделя':
          startDate = now.subtract(const Duration(days: 7));
          endDate = DateTime(now.year, now.month, now.day, 23, 59, 59);
          break;
        case 'Месяц':
          startDate = now.subtract(const Duration(days: 30));
          endDate = DateTime(now.year, now.month, now.day, 23, 59, 59);
          break;
        default:
          startDate = now.subtract(const Duration(days: 30));
          endDate = DateTime(now.year, now.month, now.day, 23, 59, 59);
          break;
      }
    }

    print('Выбранный период: $_selectedPeriod, Диапазон: $startDate - $endDate');
    return {
      'start': Timestamp.fromDate(startDate),
      'end': Timestamp.fromDate(endDate),
    };
  }

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
    Map<String, double> buyTotals = {}; // Для подсчета итоговых сумм (в сомах)
    Map<String, double> sellTotals = {}; // Для подсчета итоговых сумм (в сомах)
    Map<String, double> buyAvgRates = {}; // Средневзвешенный курс покупки
    Map<String, double> profits = {}; // Прибыль по каждой валюте

    // Сортируем транзакции по дате, чтобы правильно учитывать последовательность операций
    transactions.sort((a, b) => a.transactionDate.compareTo(b.transactionDate));

    // Проходим по всем транзакциям для подсчета сумм и количества
    for (var tx in transactions) {
      if (tx.type == 'custom' && (tx.amount == 0 || tx.total == 0)) {
        continue;
      }
      if (tx.type == 'buy') {
        buyAmounts[tx.currency] = (buyAmounts[tx.currency] ?? 0) + tx.amount;
        buyTotals[tx.currency] = (buyTotals[tx.currency] ?? 0) + tx.total;
        buyCounts[tx.currency] = (buyCounts[tx.currency] ?? 0) + 1;
      } else if (tx.type == 'sell') {
        sellAmounts[tx.currency] = (sellAmounts[tx.currency] ?? 0) + tx.amount;
        sellTotals[tx.currency] = (sellTotals[tx.currency] ?? 0) + tx.total;
        sellCounts[tx.currency] = (sellCounts[tx.currency] ?? 0) + 1;
      }
    }

    // Рассчитываем средневзвешенный курс покупки для каждой валюты
    for (var currency in buyAmounts.keys) {
      buyAvgRates[currency] = buyAmounts[currency]! > 0 ? (buyTotals[currency]! / buyAmounts[currency]!) : 0;
    }

    // Рассчитываем прибыль с учетом остатков
    for (var currency in buyAmounts.keys) {
      double bought = buyAmounts[currency] ?? 0;
      double sold = sellAmounts[currency] ?? 0;
      double avgBuyRate = buyAvgRates[currency] ?? 0;

      if (sold == 0) {
        // Если ничего не продано, прибыль 0
        profits[currency] = 0;
      } else {
        // Рассчитываем прибыль только по проданному объему
        double soldAmountInSom = sellTotals[currency] ?? 0; // Сумма продаж в сомах
        double boughtAmountForSoldInSom = sold * avgBuyRate; // Сколько стоило купить проданный объем
        double profit = soldAmountInSom - boughtAmountForSoldInSom;

        // Если есть остаток (куплено больше, чем продано), прибыль не должна быть отрицательной
        if (bought > sold && profit < 0) {
          profits[currency] = 0;
        } else {
          profits[currency] = profit;
        }
      }
    }

    double totalBuyAmount = buyTotals.values.fold(0, (sum, amount) => sum + amount);
    double totalSellAmount = sellTotals.values.fold(0, (sum, amount) => sum + amount);
    double totalTurnover = totalBuyAmount + totalSellAmount;
    double totalProfit = profits.values.fold(0, (sum, profit) => sum + profit);

    return {
      'buyAmounts': buyAmounts,
      'sellAmounts': sellAmounts,
      'buyCounts': buyCounts,
      'sellCounts': sellCounts,
      'buyTotals': buyTotals,
      'sellTotals': sellTotals,
      'buyAvgRates': buyAvgRates,
      'profits': profits,
      'totalTurnover': totalTurnover,
      'totalProfit': totalProfit,
      'totalBuyAmount': totalBuyAmount,
      'totalSellAmount': totalSellAmount,
    };
  }

  Map<String, dynamic> _calculateDailyStats(List<CashTransaction> transactions, DateTime startDate, DateTime endDate) {
    Map<String, Map<DateTime, double>> dailyBuyAmounts = {};
    Map<String, Map<DateTime, double>> dailySellAmounts = {};
    Map<String, Map<DateTime, double>> dailyBuyTotals = {};
    Map<String, Map<DateTime, double>> dailySellTotals = {};
    Map<String, Map<DateTime, int>> dailyBuyCounts = {};
    Map<String, Map<DateTime, int>> dailySellCounts = {};
    Map<String, Map<DateTime, double>> dailyProfits = {};
    Map<String, Map<DateTime, double>> dailyBuyAvgRates = {};

    // Инициализация словарей для каждой валюты и каждого дня
    for (var currency in transactions.map((tx) => tx.currency).toSet()) {
      dailyBuyAmounts[currency] = {};
      dailySellAmounts[currency] = {};
      dailyBuyTotals[currency] = {};
      dailySellTotals[currency] = {};
      dailyBuyCounts[currency] = {};
      dailySellCounts[currency] = {};
      dailyProfits[currency] = {};
      dailyBuyAvgRates[currency] = {};

      DateTime currentDate = DateTime(startDate.year, startDate.month, startDate.day);
      while (currentDate.isBefore(endDate) || currentDate.isAtSameMomentAs(endDate)) {
        dailyBuyAmounts[currency]![currentDate] = 0;
        dailySellAmounts[currency]![currentDate] = 0;
        dailyBuyTotals[currency]![currentDate] = 0;
        dailySellTotals[currency]![currentDate] = 0;
        dailyBuyCounts[currency]![currentDate] = 0;
        dailySellCounts[currency]![currentDate] = 0;
        dailyProfits[currency]![currentDate] = 0;
        dailyBuyAvgRates[currency]![currentDate] = 0;
        currentDate = currentDate.add(const Duration(days: 1));
      }
    }

    // Подсчет сумм и количества операций по дням
    for (var tx in transactions) {
      if (tx.type == 'custom' && (tx.amount == 0 || tx.total == 0)) {
        continue;
      }
      DateTime txDate = DateTime(tx.transactionDate.year, tx.transactionDate.month, tx.transactionDate.day);
      if (tx.type == 'buy') {
        dailyBuyAmounts[tx.currency]![txDate] = (dailyBuyAmounts[tx.currency]![txDate] ?? 0) + tx.amount;
        dailyBuyTotals[tx.currency]![txDate] = (dailyBuyTotals[tx.currency]![txDate] ?? 0) + tx.total;
        dailyBuyCounts[tx.currency]![txDate] = (dailyBuyCounts[tx.currency]![txDate] ?? 0) + 1;
      } else if (tx.type == 'sell') {
        dailySellAmounts[tx.currency]![txDate] = (dailySellAmounts[tx.currency]![txDate] ?? 0) + tx.amount;
        dailySellTotals[tx.currency]![txDate] = (dailySellTotals[tx.currency]![txDate] ?? 0) + tx.total;
        dailySellCounts[tx.currency]![txDate] = (dailySellCounts[tx.currency]![txDate] ?? 0) + 1;
      }
    }

    // Рассчитываем средневзвешенный курс покупки и прибыль по дням
    for (var currency in transactions.map((tx) => tx.currency).toSet()) {
      double cumulativeBuyAmount = 0;
      double cumulativeBuyTotal = 0;

      DateTime currentDate = DateTime(startDate.year, startDate.month, startDate.day);
      while (currentDate.isBefore(endDate) || currentDate.isAtSameMomentAs(endDate)) {
        // Обновляем кумулятивные значения для покупок
        cumulativeBuyAmount += dailyBuyAmounts[currency]![currentDate] ?? 0;
        cumulativeBuyTotal += dailyBuyTotals[currency]![currentDate] ?? 0;

        // Рассчитываем средневзвешенный курс покупки на текущий день
        double avgBuyRate = cumulativeBuyAmount > 0 ? cumulativeBuyTotal / cumulativeBuyAmount : 0;
        dailyBuyAvgRates[currency]![currentDate] = avgBuyRate;

        // Рассчитываем прибыль на текущий день
        double sold = dailySellAmounts[currency]![currentDate] ?? 0;
        if (sold > 0) {
          double soldAmountInSom = dailySellTotals[currency]![currentDate] ?? 0;
          double boughtAmountForSoldInSom = sold * avgBuyRate;
          double profit = soldAmountInSom - boughtAmountForSoldInSom;

          // Если на текущий день есть остаток (кумулятивно куплено больше, чем продано), прибыль не должна быть отрицательной
          double cumulativeSold = 0;
          DateTime tempDate = DateTime(startDate.year, startDate.month, startDate.day);
          while (tempDate.isBefore(currentDate) || tempDate.isAtSameMomentAs(currentDate)) {
            cumulativeSold += dailySellAmounts[currency]![tempDate] ?? 0;
            tempDate = tempDate.add(const Duration(days: 1));
          }
          if (cumulativeBuyAmount > cumulativeSold && profit < 0) {
            dailyProfits[currency]![currentDate] = 0;
          } else {
            dailyProfits[currency]![currentDate] = profit;
          }
        } else {
          dailyProfits[currency]![currentDate] = 0;
        }

        currentDate = currentDate.add(const Duration(days: 1));
      }
    }

    return {
      'dailyBuyAmounts': dailyBuyAmounts,
      'dailySellAmounts': dailySellAmounts,
      'dailyBuyTotals': dailyBuyTotals,
      'dailySellTotals': dailySellTotals,
      'dailyBuyCounts': dailyBuyCounts,
      'dailySellCounts': dailySellCounts,
      'dailyProfits': dailyProfits,
      'dailyBuyAvgRates': dailyBuyAvgRates,
    };
  }

  Future<void> _clearEvents() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final eventsRef = FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('events');
    final snapshot = await eventsRef.get();
    for (var doc in snapshot.docs) {
      await doc.reference.delete();
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Все транзакции удалены')),
    );
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
        actions: [
          IconButton(
            icon: const Icon(Icons.delete),
            onPressed: _isAuthenticated ? _clearEvents : null,
            tooltip: 'Очистить транзакции',
          ),
        ],
      ),
      body: _isAuthenticated
          ? Column(
              children: [
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
                                  _startDateController.clear();
                                  _endDateController.clear();
                                }
                              });
                            },
                          ),
                        ],
                      ),
                      if (_selectedPeriod == 'Кастомный период') ...[
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
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(16.0),
                    child: StreamBuilder<List<CashTransaction>>(
                      stream: () {
                        final dateRange = _getDateRange();
                        print('Диапазон дат: ${dateRange['start'].toDate()} - ${dateRange['end'].toDate()}');
                        return _cashService.getTransactions(
                          dateRange['start'].toDate(),
                          dateRange['end'].toDate(),
                        );
                      }(),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState == ConnectionState.waiting) {
                          print('StreamBuilder: Ожидание данных...');
                          return const Center(child: CircularProgressIndicator());
                        }
                        if (snapshot.hasError) {
                          print('StreamBuilder: Ошибка: ${snapshot.error}');
                          return Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text('Ошибка: ${snapshot.error.toString()}'),
                                const SizedBox(height: 16),
                                ElevatedButton(
                                  onPressed: () {
                                    setState(() {}); // Перезапускаем StreamBuilder
                                  },
                                  child: const Text('Повторить'),
                                ),
                              ],
                            ),
                          );
                        }
                        if (!snapshot.hasData || snapshot.data!.isEmpty) {
                          print('StreamBuilder: Нет данных. Данные: ${snapshot.data}');
                          return const Center(child: Text('Нет данных за этот период'));
                        }

                        final transactions = snapshot.data!;
                        print('StreamBuilder: Получено ${transactions.length} транзакций');
                        transactions.forEach((tx) {
                          print(
                              'Транзакция: ${tx.id}, type: ${tx.type}, amount: ${tx.amount}, total: ${tx.total}, rate: ${tx.rate}, currency: ${tx.currency}, date: ${tx.transactionDate}, userId: ${tx.userId}');
                        });

                        final dateRange = _getDateRange();
                        final startDate = dateRange['start'].toDate();
                        final endDate = dateRange['end'].toDate();
                        final stats = _calculateStats(transactions);
                        final dailyStats = _calculateDailyStats(transactions, startDate, endDate);

                        final buyAmounts = stats['buyAmounts'] as Map<String, double>;
                        final sellAmounts = stats['sellAmounts'] as Map<String, double>;
                        final buyCounts = stats['buyCounts'] as Map<String, int>;
                        final sellCounts = stats['sellCounts'] as Map<String, int>;
                        final buyTotals = stats['buyTotals'] as Map<String, double>;
                        final sellTotals = stats['sellTotals'] as Map<String, double>;
                        final buyAvgRates = stats['buyAvgRates'] as Map<String, double>;
                        final profits = stats['profits'] as Map<String, double>;
                        final totalTurnover = stats['totalTurnover'] as double;
                        final totalProfit = stats['totalProfit'] as double;
                        final totalBuyAmount = stats['totalBuyAmount'] as double;
                        final totalSellAmount = stats['totalSellAmount'] as double;

                        final dailyBuyAmounts = dailyStats['dailyBuyAmounts'] as Map<String, Map<DateTime, double>>;
                        final dailySellAmounts = dailyStats['dailySellAmounts'] as Map<String, Map<DateTime, double>>;
                        final dailyBuyCounts = dailyStats['dailyBuyCounts'] as Map<String, Map<DateTime, int>>;
                        final dailySellCounts = dailyStats['dailySellCounts'] as Map<String, Map<DateTime, int>>;
                        final dailyProfits = dailyStats['dailyProfits'] as Map<String, Map<DateTime, double>>;
                        final dailyBuyAvgRates = dailyStats['dailyBuyAvgRates'] as Map<String, Map<DateTime, double>>;

                        List<String> currencies = buyAmounts.keys.followedBy(sellAmounts.keys).toSet().toList();
                        List<DataRow> rows = currencies.map((currency) {
                          double buyAvg = buyAvgRates[currency] ?? 0;
                          double sellAvg = (sellAmounts[currency] ?? 0) > 0
                              ? (sellTotals[currency] ?? 0) / sellAmounts[currency]!
                              : 0;
                          double profit = profits[currency] ?? 0;

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

                        List<PieChartSectionData> buyCountSections = [];
                        List<PieChartSectionData> sellCountSections = [];
                        List<PieChartSectionData> buyAmountSections = [];
                        List<PieChartSectionData> sellAmountSections = [];
                        List<PieChartSectionData> profitSections = [];

                        List<Widget> buyCountIndicators = [];
                        List<Widget> sellCountIndicators = [];
                        List<Widget> buyAmountIndicators = [];
                        List<Widget> sellAmountIndicators = [];
                        List<Widget> profitIndicators = [];

                        List<Widget> buyCountBarCharts = [];
                        List<Widget> sellCountBarCharts = [];
                        List<Widget> buyAmountBarCharts = [];
                        List<Widget> sellAmountBarCharts = [];
                        List<Widget> profitBarCharts = [];

                        Map<String, Color> currencyColors = {};
                        currencies.asMap().forEach((index, currency) {
                          currencyColors[currency] = Colors.primaries[index % Colors.primaries.length];
                        });

                        if (_chartType == 'Количество операций') {
                          double totalBuyCount = buyCounts.values.fold(0, (sum, count) => sum + count).toDouble();
                          double totalSellCount = sellCounts.values.fold(0, (sum, count) => sum + count).toDouble();

                          buyCountSections = currencies.asMap().entries.map((entry) {
                            int idx = entry.key;
                            String currency = entry.value;
                            double value = (buyCounts[currency] ?? 0).toDouble();
                            double percentage = totalBuyCount > 0 ? (value / totalBuyCount * 100) : 0;
                            Color sectionColor = Colors.primaries[idx % Colors.primaries.length];
                            buyCountIndicators.add(
                              Indicator(
                                color: sectionColor,
                                text: '$currency: ${value.toStringAsFixed(0)} (${percentage.toStringAsFixed(0)}%)',
                                isSquare: true,
                              ),
                            );
                            return PieChartSectionData(
                              color: sectionColor,
                              value: value > 0 ? value : 0.001,
                              title: currency,
                              radius: _touchedIndex == idx ? 60 : 50,
                              titleStyle: const TextStyle(fontSize: 12, color: Colors.white),
                            );
                          }).toList();

                          sellCountSections = currencies.asMap().entries.map((entry) {
                            int idx = entry.key;
                            String currency = entry.value;
                            double value = (sellCounts[currency] ?? 0).toDouble();
                            double percentage = totalSellCount > 0 ? (value / totalSellCount * 100) : 0;
                            Color sectionColor = Colors.primaries[idx % Colors.primaries.length];
                            sellCountIndicators.add(
                              Indicator(
                                color: sectionColor,
                                text: '$currency: ${value.toStringAsFixed(0)} (${percentage.toStringAsFixed(0)}%)',
                                isSquare: true,
                              ),
                            );
                            return PieChartSectionData(
                              color: sectionColor,
                              value: value > 0 ? value : 0.001,
                              title: currency,
                              radius: _touchedIndex == idx ? 60 : 50,
                              titleStyle: const TextStyle(fontSize: 12, color: Colors.white),
                            );
                          }).toList();

                          List<BarChartGroupData> buyCountBarGroups = [];
                          DateTime currentDate = DateTime(startDate.year, startDate.month, startDate.day);
                          int dayIndex = 0;
                          while (currentDate.isBefore(endDate) || currentDate.isAtSameMomentAs(endDate)) {
                            List<BarChartRodData> rods = [];
                            for (String currency in currencies) {
                              double buyValue = (dailyBuyCounts[currency]![currentDate] ?? 0).toDouble();
                              rods.add(
                                BarChartRodData(
                                  toY: buyValue,
                                  color: currencyColors[currency]!,
                                  width: 10,
                                  borderRadius: BorderRadius.zero,
                                ),
                              );
                            }
                            buyCountBarGroups.add(
                              BarChartGroupData(
                                x: dayIndex,
                                barRods: rods,
                                showingTooltipIndicators:
                                    rods.asMap().entries.where((entry) => entry.value.toY > 0).map((entry) => entry.key).toList(),
                              ),
                            );
                            currentDate = currentDate.add(const Duration(days: 1));
                            dayIndex++;
                          }

                          buyCountBarCharts.add(
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Покупки - Количество операций',
                                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                                const SizedBox(height: 8),
                                Wrap(
                                  spacing: 16,
                                  children: currencies.map((currency) {
                                    return Indicator(
                                      color: currencyColors[currency]!,
                                      text: currency,
                                      isSquare: true,
                                    );
                                  }).toList(),
                                ),
                                const SizedBox(height: 8),
                                SizedBox(
                                  height: 200,
                                  child: SingleChildScrollView(
                                    scrollDirection: Axis.horizontal,
                                    child: SizedBox(
                                      width: buyCountBarGroups.length * 40.0 * currencies.length,
                                      child: BarChart(
                                        BarChartData(
                                          barGroups: buyCountBarGroups,
                                          titlesData: FlTitlesData(
                                            bottomTitles: AxisTitles(
                                              sideTitles: SideTitles(
                                                showTitles: true,
                                                getTitlesWidget: (value, meta) {
                                                  DateTime date = startDate.add(Duration(days: value.toInt()));
                                                  return Text(
                                                    DateFormat('dd').format(date),
                                                    style: const TextStyle(fontSize: 10),
                                                  );
                                                },
                                              ),
                                            ),
                                            leftTitles: AxisTitles(
                                              sideTitles: SideTitles(
                                                showTitles: true,
                                                reservedSize: 40,
                                                getTitlesWidget: (value, meta) {
                                                  return Text(
                                                    value.toInt().toString(),
                                                    style: const TextStyle(fontSize: 10),
                                                  );
                                                },
                                              ),
                                            ),
                                            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                                            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                                          ),
                                          borderData: FlBorderData(show: true),
                                          barTouchData: BarTouchData(
                                            enabled: true,
                                            touchTooltipData: BarTouchTooltipData(
                                              getTooltipColor: (group) => Colors.grey.shade800,
                                              tooltipPadding: const EdgeInsets.all(8),
                                              tooltipMargin: 8,
                                              getTooltipItem: (group, groupIndex, rod, rodIndex) {
                                                String currency = currencies[rodIndex];
                                                return BarTooltipItem(
                                                  '$currency: ${rod.toY.toStringAsFixed(0)}',
                                                  const TextStyle(color: Colors.white),
                                                );
                                              },
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );

                          List<BarChartGroupData> sellCountBarGroups = [];
                          currentDate = DateTime(startDate.year, startDate.month, startDate.day);
                          dayIndex = 0;
                          while (currentDate.isBefore(endDate) || currentDate.isAtSameMomentAs(endDate)) {
                            List<BarChartRodData> rods = [];
                            for (String currency in currencies) {
                              double sellValue = (dailySellCounts[currency]![currentDate] ?? 0).toDouble();
                              rods.add(
                                BarChartRodData(
                                  toY: sellValue,
                                  color: currencyColors[currency]!,
                                  width: 10,
                                  borderRadius: BorderRadius.zero,
                                ),
                              );
                            }
                            sellCountBarGroups.add(
                              BarChartGroupData(
                                x: dayIndex,
                                barRods: rods,
                                showingTooltipIndicators:
                                    rods.asMap().entries.where((entry) => entry.value.toY > 0).map((entry) => entry.key).toList(),
                              ),
                            );
                            currentDate = currentDate.add(const Duration(days: 1));
                            dayIndex++;
                          }

                          sellCountBarCharts.add(
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Продажи - Количество операций',
                                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                                const SizedBox(height: 8),
                                Wrap(
                                  spacing: 16,
                                  children: currencies.map((currency) {
                                    return Indicator(
                                      color: currencyColors[currency]!,
                                      text: currency,
                                      isSquare: true,
                                    );
                                  }).toList(),
                                ),
                                const SizedBox(height: 8),
                                SizedBox(
                                  height: 200,
                                  child: SingleChildScrollView(
                                    scrollDirection: Axis.horizontal,
                                    child: SizedBox(
                                      width: sellCountBarGroups.length * 40.0 * currencies.length,
                                      child: BarChart(
                                        BarChartData(
                                          barGroups: sellCountBarGroups,
                                          titlesData: FlTitlesData(
                                            bottomTitles: AxisTitles(
                                              sideTitles: SideTitles(
                                                showTitles: true,
                                                getTitlesWidget: (value, meta) {
                                                  DateTime date = startDate.add(Duration(days: value.toInt()));
                                                  return Text(
                                                    DateFormat('dd').format(date),
                                                    style: const TextStyle(fontSize: 10),
                                                  );
                                                },
                                              ),
                                            ),
                                            leftTitles: AxisTitles(
                                              sideTitles: SideTitles(
                                                showTitles: true,
                                                reservedSize: 40,
                                                getTitlesWidget: (value, meta) {
                                                  return Text(
                                                    value.toInt().toString(),
                                                    style: const TextStyle(fontSize: 10),
                                                  );
                                                },
                                              ),
                                            ),
                                            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                                            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                                          ),
                                          borderData: FlBorderData(show: true),
                                          barTouchData: BarTouchData(
                                            enabled: true,
                                            touchTooltipData: BarTouchTooltipData(
                                              getTooltipColor: (group) => Colors.grey.shade800,
                                              tooltipPadding: const EdgeInsets.all(8),
                                              tooltipMargin: 8,
                                              getTooltipItem: (group, groupIndex, rod, rodIndex) {
                                                String currency = currencies[rodIndex];
                                                return BarTooltipItem(
                                                  '$currency: ${rod.toY.toStringAsFixed(0)}',
                                                  const TextStyle(color: Colors.white),
                                                );
                                              },
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        }

                        if (_chartType == 'Сумма покупок и продаж') {
                          buyAmountSections = currencies.asMap().entries.map((entry) {
                            int idx = entry.key;
                            String currency = entry.value;
                            double value = buyTotals[currency] ?? 0;
                            double percentage = totalBuyAmount > 0 ? (value / totalBuyAmount * 100) : 0;
                            Color sectionColor = Colors.primaries[idx % Colors.primaries.length];
                            buyAmountIndicators.add(
                              Indicator(
                                color: sectionColor,
                                text: '$currency: ${value.toStringAsFixed(2)} сом (${percentage.toStringAsFixed(0)}%)',
                                isSquare: true,
                              ),
                            );
                            return PieChartSectionData(
                              color: sectionColor,
                              value: value > 0 ? value : 0.001,
                              title: currency,
                              radius: _touchedIndex == idx ? 60 : 50,
                              titleStyle: const TextStyle(fontSize: 12, color: Colors.white),
                            );
                          }).toList();

                          sellAmountSections = currencies.asMap().entries.map((entry) {
                            int idx = entry.key;
                            String currency = entry.value;
                            double value = sellTotals[currency] ?? 0;
                            double percentage = totalSellAmount > 0 ? (value / totalSellAmount * 100) : 0;
                            Color sectionColor = Colors.primaries[idx % Colors.primaries.length];
                            sellAmountIndicators.add(
                              Indicator(
                                color: sectionColor,
                                text: '$currency: ${value.toStringAsFixed(2)} сом (${percentage.toStringAsFixed(0)}%)',
                                isSquare: true,
                              ),
                            );
                            return PieChartSectionData(
                              color: sectionColor,
                              value: value > 0 ? value : 0.001,
                              title: currency,
                              radius: _touchedIndex == idx ? 60 : 50,
                              titleStyle: const TextStyle(fontSize: 12, color: Colors.white),
                            );
                          }).toList();

                          List<BarChartGroupData> buyAmountBarGroups = [];
                          DateTime currentDate = DateTime(startDate.year, startDate.month, startDate.day);
                          int dayIndex = 0;
                          while (currentDate.isBefore(endDate) || currentDate.isAtSameMomentAs(endDate)) {
                            List<BarChartRodData> rods = [];
                            for (String currency in currencies) {
                              double buyValue = dailyBuyAmounts[currency]![currentDate] ?? 0;
                              double buyRate = dailyBuyAvgRates[currency]![currentDate] ?? 0;
                              double buyValueInSom = buyValue * buyRate;
                              rods.add(
                                BarChartRodData(
                                  toY: buyValueInSom,
                                  color: currencyColors[currency]!,
                                  width: 10,
                                  borderRadius: BorderRadius.zero,
                                ),
                              );
                            }
                            buyAmountBarGroups.add(
                              BarChartGroupData(
                                x: dayIndex,
                                barRods: rods,
                                showingTooltipIndicators:
                                    rods.asMap().entries.where((entry) => entry.value.toY > 0).map((entry) => entry.key).toList(),
                              ),
                            );
                            currentDate = currentDate.add(const Duration(days: 1));
                            dayIndex++;
                          }

                          buyAmountBarCharts.add(
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Сумма покупок (в сомах)', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                                const SizedBox(height: 8),
                                Wrap(
                                  spacing: 16,
                                  children: currencies.map((currency) {
                                    return Indicator(
                                      color: currencyColors[currency]!,
                                      text: currency,
                                      isSquare: true,
                                    );
                                  }).toList(),
                                ),
                                const SizedBox(height: 8),
                                SizedBox(
                                  height: 200,
                                  child: SingleChildScrollView(
                                    scrollDirection: Axis.horizontal,
                                    child: SizedBox(
                                      width: buyAmountBarGroups.length * 40.0 * currencies.length,
                                      child: BarChart(
                                        BarChartData(
                                          barGroups: buyAmountBarGroups,
                                          titlesData: FlTitlesData(
                                            bottomTitles: AxisTitles(
                                              sideTitles: SideTitles(
                                                showTitles: true,
                                                getTitlesWidget: (value, meta) {
                                                  DateTime date = startDate.add(Duration(days: value.toInt()));
                                                  return Text(
                                                    DateFormat('dd').format(date),
                                                    style: const TextStyle(fontSize: 10),
                                                  );
                                                },
                                              ),
                                            ),
                                            leftTitles: AxisTitles(
                                              sideTitles: SideTitles(
                                                showTitles: true,
                                                reservedSize: 40,
                                                getTitlesWidget: (value, meta) {
                                                  return Text(
                                                    value.toInt().toString(),
                                                    style: const TextStyle(fontSize: 10),
                                                  );
                                                },
                                              ),
                                            ),
                                            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                                            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                                          ),
                                          borderData: FlBorderData(show: true),
                                          barTouchData: BarTouchData(
                                            enabled: true,
                                            touchTooltipData: BarTouchTooltipData(
                                              getTooltipColor: (group) => Colors.grey.shade800,
                                              tooltipPadding: const EdgeInsets.all(8),
                                              tooltipMargin: 8,
                                              getTooltipItem: (group, groupIndex, rod, rodIndex) {
                                                String currency = currencies[rodIndex];
                                                return BarTooltipItem(
                                                  '$currency: ${rod.toY.toStringAsFixed(2)} сом',
                                                  const TextStyle(color: Colors.white),
                                                );
                                              },
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );

                          List<BarChartGroupData> sellAmountBarGroups = [];
                          currentDate = DateTime(startDate.year, startDate.month, startDate.day);
                          dayIndex = 0;
                          while (currentDate.isBefore(endDate) || currentDate.isAtSameMomentAs(endDate)) {
                            List<BarChartRodData> rods = [];
                            for (String currency in currencies) {
                              double sellValue = dailySellAmounts[currency]![currentDate] ?? 0;
                              double sellRate = (sellTotals[currency] ?? 0) / (sellAmounts[currency] ?? 1);
                              double sellValueInSom = sellValue * sellRate;
                              rods.add(
                                BarChartRodData(
                                  toY: sellValueInSom,
                                  color: currencyColors[currency]!,
                                  width: 10,
                                  borderRadius: BorderRadius.zero,
                                ),
                              );
                            }
                            sellAmountBarGroups.add(
                              BarChartGroupData(
                                x: dayIndex,
                                barRods: rods,
                                showingTooltipIndicators:
                                    rods.asMap().entries.where((entry) => entry.value.toY > 0).map((entry) => entry.key).toList(),
                              ),
                            );
                            currentDate = currentDate.add(const Duration(days: 1));
                            dayIndex++;
                          }

                          sellAmountBarCharts.add(
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Сумма продаж (в сомах)', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                                const SizedBox(height: 8),
                                Wrap(
                                  spacing: 16,
                                  children: currencies.map((currency) {
                                    return Indicator(
                                      color: currencyColors[currency]!,
                                      text: currency,
                                      isSquare: true,
                                    );
                                  }).toList(),
                                ),
                                const SizedBox(height: 8),
                                SizedBox(
                                  height: 200,
                                  child: SingleChildScrollView(
                                    scrollDirection: Axis.horizontal,
                                    child: SizedBox(
                                      width: sellAmountBarGroups.length * 40.0 * currencies.length,
                                      child: BarChart(
                                        BarChartData(
                                          barGroups: sellAmountBarGroups,
                                          titlesData: FlTitlesData(
                                            bottomTitles: AxisTitles(
                                              sideTitles: SideTitles(
                                                showTitles: true,
                                                getTitlesWidget: (value, meta) {
                                                  DateTime date = startDate.add(Duration(days: value.toInt()));
                                                  return Text(
                                                    DateFormat('dd').format(date),
                                                    style: const TextStyle(fontSize: 10),
                                                  );
                                                },
                                              ),
                                            ),
                                            leftTitles: AxisTitles(
                                              sideTitles: SideTitles(
                                                showTitles: true,
                                                reservedSize: 40,
                                                getTitlesWidget: (value, meta) {
                                                  return Text(
                                                    value.toInt().toString(),
                                                    style: const TextStyle(fontSize: 10),
                                                  );
                                                },
                                              ),
                                            ),
                                            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                                            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                                          ),
                                          borderData: FlBorderData(show: true),
                                          barTouchData: BarTouchData(
                                            enabled: true,
                                            touchTooltipData: BarTouchTooltipData(
                                              getTooltipColor: (group) => Colors.grey.shade800,
                                              tooltipPadding: const EdgeInsets.all(8),
                                              tooltipMargin: 8,
                                              getTooltipItem: (group, groupIndex, rod, rodIndex) {
                                                String currency = currencies[rodIndex];
                                                return BarTooltipItem(
                                                  '$currency: ${rod.toY.toStringAsFixed(2)} сом',
                                                  const TextStyle(color: Colors.white),
                                                );
                                              },
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        }

                        if (_chartType == 'Прибыль') {
                          double totalProfitForPercentage = profits.values.fold(0, (sum, profit) => sum + profit);
                          profitSections = currencies.asMap().entries.map((entry) {
                            int idx = entry.key;
                            String currency = entry.value;
                            double profit = profits[currency] ?? 0;
                            double percentage = totalProfitForPercentage != 0 ? (profit / totalProfitForPercentage * 100) : 0;
                            Color sectionColor = Colors.primaries[idx % Colors.primaries.length];
                            profitIndicators.add(
                              Indicator(
                                color: sectionColor,
                                text: '$currency: ${profit.toStringAsFixed(2)} сом (${percentage.toStringAsFixed(0)}%)',
                                isSquare: true,
                              ),
                            );
                            return PieChartSectionData(
                              color: sectionColor,
                              value: profit != 0 ? profit.abs() : 0.001,
                              title: currency,
                              radius: _touchedIndex == idx ? 60 : 50,
                              titleStyle: const TextStyle(fontSize: 12, color: Colors.white),
                            );
                          }).toList();

                          List<BarChartGroupData> profitBarGroups = [];
                          DateTime currentDate = DateTime(startDate.year, startDate.month, startDate.day);
                          int dayIndex = 0;
                          while (currentDate.isBefore(endDate) || currentDate.isAtSameMomentAs(endDate)) {
                            List<BarChartRodData> rods = [];
                            for (String currency in currencies) {
                              double profitValue = dailyProfits[currency]![currentDate] ?? 0;
                              rods.add(
                                BarChartRodData(
                                  toY: profitValue,
                                  color: currencyColors[currency]!,
                                  width: 10,
                                  borderRadius: BorderRadius.zero,
                                ),
                              );
                            }
                            profitBarGroups.add(
                              BarChartGroupData(
                                x: dayIndex,
                                barRods: rods,
                                showingTooltipIndicators:
                                    rods.asMap().entries.where((entry) => entry.value.toY != 0).map((entry) => entry.key).toList(),
                              ),
                            );
                            currentDate = currentDate.add(const Duration(days: 1));
                            dayIndex++;
                          }

                          profitBarCharts.add(
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Прибыль (в сомах)', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                                const SizedBox(height: 8),
                                Wrap(
                                  spacing: 16,
                                  children: currencies.map((currency) {
                                    return Indicator(
                                      color: currencyColors[currency]!,
                                      text: currency,
                                      isSquare: true,
                                    );
                                  }).toList(),
                                ),
                                const SizedBox(height: 8),
                                SizedBox(
                                  height: 200,
                                  child: SingleChildScrollView(
                                    scrollDirection: Axis.horizontal,
                                    child: SizedBox(
                                      width: profitBarGroups.length * 40.0 * currencies.length,
                                      child: BarChart(
                                        BarChartData(
                                          barGroups: profitBarGroups,
                                          titlesData: FlTitlesData(
                                            bottomTitles: AxisTitles(
                                              sideTitles: SideTitles(
                                                showTitles: true,
                                                getTitlesWidget: (value, meta) {
                                                  DateTime date = startDate.add(Duration(days: value.toInt()));
                                                  return Text(
                                                    DateFormat('dd').format(date),
                                                    style: const TextStyle(fontSize: 10),
                                                  );
                                                },
                                              ),
                                            ),
                                            leftTitles: AxisTitles(
                                              sideTitles: SideTitles(
                                                showTitles: true,
                                                reservedSize: 40,
                                                getTitlesWidget: (value, meta) {
                                                  return Text(
                                                    value.toInt().toString(),
                                                    style: const TextStyle(fontSize: 10),
                                                  );
                                                },
                                              ),
                                            ),
                                            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                                            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                                          ),
                                          borderData: FlBorderData(show: true),
                                          barTouchData: BarTouchData(
                                            enabled: true,
                                            touchTooltipData: BarTouchTooltipData(
                                              getTooltipColor: (group) => Colors.grey.shade800,
                                              tooltipPadding: const EdgeInsets.all(8),
                                              tooltipMargin: 8,
                                              getTooltipItem: (group, groupIndex, rod, rodIndex) {
                                                String currency = currencies[rodIndex];
                                                return BarTooltipItem(
                                                  '$currency: ${rod.toY.toStringAsFixed(2)} сом',
                                                  const TextStyle(color: Colors.white),
                                                );
                                              },
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
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
                                DropdownMenuItem(value: 'Сумма покупок и продаж', child: Text('Сумма покупок и продаж')),
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
                            if (_chartType == 'Количество операций') ...[
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                children: [
                                  Column(
                                    children: [
                                      const Text('Покупки', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                                      SizedBox(
                                        height: 200,
                                        width: 200,
                                        child: PieChart(
                                          PieChartData(
                                            sections: buyCountSections,
                                            sectionsSpace: 2,
                                            centerSpaceRadius: 40,
                                            startDegreeOffset: 90,
                                            pieTouchData: PieTouchData(
                                              touchCallback: (FlTouchEvent event, pieTouchResponse) {
                                                if (event is FlTapDownEvent) {
                                                  setState(() {
                                                    if (pieTouchResponse == null || pieTouchResponse.touchedSection == null) {
                                                      _touchedIndex = -1;
                                                      return;
                                                    }
                                                    _touchedIndex = pieTouchResponse.touchedSection!.touchedSectionIndex;
                                                  });
                                                }
                                                if (event is FlTapUpEvent) {
                                                  setState(() {
                                                    _touchedIndex = -1;
                                                  });
                                                }
                                              },
                                            ),
                                          ),
                                          swapAnimationDuration: const Duration(milliseconds: 800),
                                          swapAnimationCurve: Curves.easeInOut,
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: buyCountIndicators,
                                      ),
                                    ],
                                  ),
                                  Column(
                                    children: [
                                      const Text('Продажи', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                                      SizedBox(
                                        height: 200,
                                        width: 200,
                                        child: PieChart(
                                          PieChartData(
                                            sections: sellCountSections,
                                            sectionsSpace: 2,
                                            centerSpaceRadius: 40,
                                            startDegreeOffset: 90,
                                            pieTouchData: PieTouchData(
                                              touchCallback: (FlTouchEvent event, pieTouchResponse) {
                                                if (event is FlTapDownEvent) {
                                                  setState(() {
                                                    if (pieTouchResponse == null || pieTouchResponse.touchedSection == null) {
                                                      _touchedIndex = -1;
                                                      return;
                                                    }
                                                    _touchedIndex = pieTouchResponse.touchedSection!.touchedSectionIndex;
                                                  });
                                                }
                                                if (event is FlTapUpEvent) {
                                                  setState(() {
                                                    _touchedIndex = -1;
                                                  });
                                                }
                                              },
                                            ),
                                          ),
                                          swapAnimationDuration: const Duration(milliseconds: 800),
                                          swapAnimationCurve: Curves.easeInOut,
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: sellCountIndicators,
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                              const SizedBox(height: 20),
                              const Text('Гистограммы по дням:', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                              const SizedBox(height: 10),
                              ...buyCountBarCharts,
                              const SizedBox(height: 20),
                              ...sellCountBarCharts,
                            ],
                            if (_chartType == 'Сумма покупок и продаж') ...[
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                children: [
                                  Column(
                                    children: [
                                      const Text('Сумма покупок', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                                      SizedBox(
                                        height: 200,
                                        width: 200,
                                        child: PieChart(
                                          PieChartData(
                                            sections: buyAmountSections,
                                            sectionsSpace: 2,
                                            centerSpaceRadius: 40,
                                            startDegreeOffset: 90,
                                            pieTouchData: PieTouchData(
                                              touchCallback: (FlTouchEvent event, pieTouchResponse) {
                                                if (event is FlTapDownEvent) {
                                                  setState(() {
                                                    if (pieTouchResponse == null || pieTouchResponse.touchedSection == null) {
                                                      _touchedIndex = -1;
                                                      return;
                                                    }
                                                    _touchedIndex = pieTouchResponse.touchedSection!.touchedSectionIndex;
                                                  });
                                                }
                                                if (event is FlTapUpEvent) {
                                                  setState(() {
                                                    _touchedIndex = -1;
                                                  });
                                                }
                                              },
                                            ),
                                          ),
                                          swapAnimationDuration: const Duration(milliseconds: 800),
                                          swapAnimationCurve: Curves.easeInOut,
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: buyAmountIndicators,
                                      ),
                                    ],
                                  ),
                                  Column(
                                    children: [
                                      const Text('Сумма продаж', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                                      SizedBox(
                                        height: 200,
                                        width: 200,
                                        child: PieChart(
                                          PieChartData(
                                            sections: sellAmountSections,
                                            sectionsSpace: 2,
                                            centerSpaceRadius: 40,
                                            startDegreeOffset: 90,
                                            pieTouchData: PieTouchData(
                                              touchCallback: (FlTouchEvent event, pieTouchResponse) {
                                                if (event is FlTapDownEvent) {
                                                  setState(() {
                                                    if (pieTouchResponse == null || pieTouchResponse.touchedSection == null) {
                                                      _touchedIndex = -1;
                                                      return;
                                                    }
                                                    _touchedIndex = pieTouchResponse.touchedSection!.touchedSectionIndex;
                                                  });
                                                }
                                                if (event is FlTapUpEvent) {
                                                  setState(() {
                                                    _touchedIndex = -1;
                                                  });
                                                }
                                              },
                                            ),
                                          ),
                                          swapAnimationDuration: const Duration(milliseconds: 800),
                                          swapAnimationCurve: Curves.easeInOut,
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: sellAmountIndicators,
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                              const SizedBox(height: 20),
                              const Text('Гистограммы по дням:', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                              const SizedBox(height: 10),
                              ...buyAmountBarCharts,
                              const SizedBox(height: 20),
                              ...sellAmountBarCharts,
                            ],
                            if (_chartType == 'Прибыль') ...[
                              Column(
                                children: [
                                  SizedBox(
                                    height: 200,
                                    child: PieChart(
                                      PieChartData(
                                        sections: profitSections,
                                        sectionsSpace: 2,
                                        centerSpaceRadius: 40,
                                        startDegreeOffset: 90,
                                        pieTouchData: PieTouchData(
                                          touchCallback: (FlTouchEvent event, pieTouchResponse) {
                                            if (event is FlTapDownEvent) {
                                              setState(() {
                                                if (pieTouchResponse == null || pieTouchResponse.touchedSection == null) {
                                                  _touchedIndex = -1;
                                                  return;
                                                }
                                                _touchedIndex = pieTouchResponse.touchedSection!.touchedSectionIndex;
                                              });
                                            }
                                            if (event is FlTapUpEvent) {
                                              setState(() {
                                                _touchedIndex = -1;
                                              });
                                            }
                                          },
                                        ),
                                      ),
                                      swapAnimationDuration: const Duration(milliseconds: 800),
                                      swapAnimationCurve: Curves.easeInOut,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: profitIndicators,
                                  ),
                                ],
                              ),
                              const SizedBox(height: 20),
                              const Text('Гистограммы по дням:', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                              const SizedBox(height: 10),
                              ...profitBarCharts,
                            ],
                            const SizedBox(height: 20),
                            const Text('Итоги:', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                            Text('Общий оборот: ${totalTurnover.toStringAsFixed(2)}'),
                            Text('Общая прибыль: ${totalProfit.toStringAsFixed(2)}'),
                            const SizedBox(height: 20),
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