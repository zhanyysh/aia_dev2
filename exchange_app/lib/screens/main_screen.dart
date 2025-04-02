import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:exchange_app/screens/currency_screen.dart';
import 'package:exchange_app/screens/events_screen.dart';
import 'package:exchange_app/screens/converter_screen.dart';
import 'package:exchange_app/services/auth_service.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  final AuthService _authService = AuthService();
  final TextEditingController _amountController = TextEditingController();
  String? _selectedCurrency;
  double? _rate;
  double? _total;
  bool _isSelling = true; // true = Продажа (стрелка вверх), false = Покупка (стрелка вниз)

  @override
  void initState() {
    super.initState();
    _amountController.addListener(_calculateTotal);
  }

  void _calculateTotal() {
    final amount = double.tryParse(_amountController.text.trim());
    if (amount != null && _rate != null) {
      setState(() {
        _total = amount * _rate!;
      });
    } else {
      setState(() {
        _total = null;
      });
    }
  }

  Future<void> _addEvent() async {
    final amount = double.tryParse(_amountController.text.trim());
    if (amount == null || _selectedCurrency == null || _rate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Заполните все поля')),
      );
      return;
    }

    try {
      await FirebaseFirestore.instance.collection('events').add({
        'title': _isSelling ? 'Продажа $_selectedCurrency' : 'Покупка $_selectedCurrency',
        'description': '${_isSelling ? "Продано" : "Куплено"} $amount $_selectedCurrency по курсу $_rate. Итог: $_total',
        'currency': _selectedCurrency,
        'date': Timestamp.now(),
        'type': _isSelling ? 'sell' : 'buy',
        'amount': amount,
        'rate': _rate,
        'total': _total,
      });
      _amountController.clear();
      setState(() {
        _total = null;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Транзакция добавлена')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ошибка: $e')),
      );
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Главная'),
        backgroundColor: Colors.blueAccent,
      ),
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            DrawerHeader(
              decoration: BoxDecoration(
                color: Colors.blueAccent,
              ),
              child: Text(
                'Меню',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                ),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.monetization_on),
              title: const Text('Валюты'),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const CurrencyScreen()),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.event),
              title: const Text('События'),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const EventsScreen()),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.calculate),
              title: const Text('Конвертер'),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const ConverterScreen()),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.logout),
              title: const Text('Выйти'),
              onTap: () async {
                await _authService.signOut();
                Navigator.pushNamedAndRemoveUntil(
                  context,
                  '/login',
                  (Route<dynamic> route) => false,
                );
              },
            ),
          ],
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton.icon(
                  onPressed: () {
                    setState(() {
                      _isSelling = true;
                    });
                  },
                  icon: const Icon(Icons.arrow_upward),
                  label: const Text('Продажа'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _isSelling ? Colors.blueAccent : Colors.grey,
                  ),
                ),
                const SizedBox(width: 16),
                ElevatedButton.icon(
                  onPressed: () {
                    setState(() {
                      _isSelling = false;
                    });
                  },
                  icon: const Icon(Icons.arrow_downward),
                  label: const Text('Покупка'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: !_isSelling ? Colors.blueAccent : Colors.grey,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance.collection('currencies').snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const CircularProgressIndicator();
                }
                final currencies = snapshot.data!.docs;
                final currencyNames = currencies.map((doc) => doc.id).toList();

                return DropdownButtonFormField<String>(
                  decoration: const InputDecoration(
                    labelText: 'Выбор валюты',
                    border: OutlineInputBorder(),
                  ),
                  value: _selectedCurrency,
                  items: currencyNames.map((name) {
                    return DropdownMenuItem<String>(
                      value: name,
                      child: Text(name),
                    );
                  }).toList(),
                  onChanged: (value) async {
                    setState(() {
                      _selectedCurrency = value;
                    });
                    if (value != null) {
                      final doc = await FirebaseFirestore.instance.collection('currencies').doc(value).get();
                      if (doc.exists) {
                        setState(() {
                          _rate = (doc.data()!['rate'] as num).toDouble();
                        });
                        _calculateTotal();
                      }
                    }
                  },
                );
              },
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _amountController,
              decoration: const InputDecoration(
                labelText: 'Количество',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 16),
            Text(
              'Курс: ${_rate?.toStringAsFixed(2) ?? "Выберите валюту"}',
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 16),
            Text(
              'Итог: ${_total?.toStringAsFixed(2) ?? "0.00"} ${_selectedCurrency ?? ""}',
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 24),
            Center(
              child: ElevatedButton(
                onPressed: _addEvent,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blueAccent,
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                ),
                child: const Text(
                  'Добавить',
                  style: TextStyle(fontSize: 16),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
} 