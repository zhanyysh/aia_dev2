//main_screen.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:exchange_app/screens/cash_screen.dart';
import 'package:exchange_app/screens/currency_screen.dart';
import 'package:exchange_app/screens/events_screen.dart';
import 'package:exchange_app/screens/login_screen.dart';
import 'package:exchange_app/services/auth_service.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  final TextEditingController _amountController = TextEditingController();
  String? _selectedCurrency;
  double? _rate;
  double? _total;
  bool _isSelling = true; // true = Продажа (стрелка вверх), false = Покупка (стрелка вниз)
  final AuthService _authService = AuthService();

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
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Пользователь не авторизован')),
      );
      return;
    }

    final amount = double.tryParse(_amountController.text.trim());
    if (amount == null || _selectedCurrency == null || _rate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Заполните все поля')),
      );
      return;
    }

    try {
      // Проверяем, существует ли документ для выбранной валюты в коллекции currencies
      final currencyDocRef = FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('currencies')
          .doc(_selectedCurrency);

      final currencyDoc = await currencyDocRef.get();
      if (!currencyDoc.exists) {
        // Если документа нет, создаем его с начальным значением курса
        await currencyDocRef.set({
          'rate': _rate,
        });
      } else {
        // Если документ существует, обновляем курс
        await currencyDocRef.update({
          'rate': _rate,
        });
      }

      // Добавляем транзакцию в events с нужными полями
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('events')
          .add({
        'currency': _selectedCurrency,
        'date': Timestamp.now(),
        'type': _isSelling ? 'sell' : 'buy',
        'amount': amount,
        'rate': _rate,
        'total': _total,
        'month': '', // Поле month оставляем пустым, как в базе данных
      });

      // Очищаем поля после успешной транзакции
      _amountController.clear();
      setState(() {
        _total = null;
        _selectedCurrency = null;
        _rate = null;
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
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const Scaffold(
        body: Center(child: Text('Пользователь не авторизован')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Exchange-app'),
        backgroundColor: Colors.blueAccent,
        elevation: 0,
      ),
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: <Widget>[
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
              leading: Icon(Icons.home),
              title: Text('Главная'),
              onTap: () {
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: Icon(Icons.history),
              title: Text('История'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const EventsScreen()),
                );
              },
            ),
            ListTile(
              leading: Icon(Icons.account_balance_wallet),
              title: Text('Касса'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const CashScreen()),
                );
              },
            ),
            ListTile(
              leading: Icon(Icons.currency_exchange),
              title: Text('Валюты'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const CurrencyScreen()),
                );
              },
            ),
            ListTile(
              leading: Icon(Icons.logout),
              title: Text('Выйти'),
              onTap: () {
                _authService.signOut().then((_) {
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(builder: (context) => const LoginScreen()),
                  );
                });
              },
            ),
          ],
        ),
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.blue.shade50, Colors.white],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    child: IconButton(
                      onPressed: () {
                        setState(() {
                          _isSelling = true;
                        });
                      },
                      icon: Icon(
                        Icons.arrow_upward,
                        color: _isSelling ? Colors.blueAccent : Colors.grey,
                        size: 30,
                      ),
                      style: IconButton.styleFrom(
                        backgroundColor: _isSelling ? Colors.blueAccent.withOpacity(0.1) : Colors.grey.withOpacity(0.1),
                        padding: const EdgeInsets.all(12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    child: IconButton(
                      onPressed: () {
                        setState(() {
                          _isSelling = false;
                        });
                      },
                      icon: Icon(
                        Icons.arrow_downward,
                        color: !_isSelling ? Colors.blueAccent : Colors.grey,
                        size: 30,
                      ),
                      style: IconButton.styleFrom(
                        backgroundColor: !_isSelling ? Colors.blueAccent.withOpacity(0.1) : Colors.grey.withOpacity(0.1),
                        padding: const EdgeInsets.all(12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('users')
                    .doc(user.uid)
                    .collection('currencies')
                    .snapshots(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final currencies = snapshot.data!.docs;
                  final currencyNames = currencies.map((doc) => doc.id).toList();

                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade200,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.grey.withOpacity(0.2),
                          spreadRadius: 2,
                          blurRadius: 5,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: DropdownButtonFormField<String>(
                      decoration: const InputDecoration(
                        labelText: 'Валюта',
                        border: InputBorder.none,
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
                          final doc = await FirebaseFirestore.instance
                              .collection('users')
                              .doc(user.uid)
                              .collection('currencies')
                              .doc(value)
                              .get();
                          if (doc.exists) {
                            setState(() {
                              _rate = (doc.data()!['rate'] as num?)?.toDouble();
                            });
                            _calculateTotal();
                          }
                        }
                      },
                    ),
                  );
                },
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.grey.shade200,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.grey.withOpacity(0.2),
                      spreadRadius: 2,
                      blurRadius: 5,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: TextField(
                  controller: _amountController,
                  decoration: const InputDecoration(
                    labelText: 'Кол-во',
                    border: InputBorder.none,
                  ),
                  keyboardType: TextInputType.number,
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.grey.shade200,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.grey.withOpacity(0.2),
                      spreadRadius: 2,
                      blurRadius: 5,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: TextField(
                  onChanged: (value) {
                    setState(() {
                      _rate = double.tryParse(value);
                    });
                    _calculateTotal();
                  },
                  decoration: const InputDecoration(
                    labelText: 'Курс',
                    border: InputBorder.none,
                  ),
                  keyboardType: TextInputType.number,
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                decoration: BoxDecoration(
                  color: Colors.grey.shade200,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.grey.withOpacity(0.2),
                      spreadRadius: 2,
                      blurRadius: 5,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Text(
                  'Итого (Курс * Кол-во): ${_total?.toStringAsFixed(2) ?? "0.00"} ${_selectedCurrency ?? ""}',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(height: 24),
              Center(
                child: ElevatedButton(
                  onPressed: _addEvent,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.grey.shade300,
                    padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 5,
                  ),
                  child: const Text(
                    'Выполнить',
                    style: TextStyle(fontSize: 16, color: Colors.black),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}