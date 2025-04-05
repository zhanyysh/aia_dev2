import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:exchange_app/screens/currency_screen.dart';
import 'package:exchange_app/screens/login_screen.dart';
import 'package:exchange_app/screens/users_screen.dart';
import 'package:exchange_app/services/auth_service.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _rateController = TextEditingController();
  String? _selectedCurrency;
  double? _total;
  bool _isSelling = true; // true = Продажа (стрелка вверх), false = Покупка (стрелка вниз)
  final AuthService _authService = AuthService();

  @override
  void initState() {
    super.initState();
    _amountController.addListener(_calculateTotal);
    _rateController.addListener(_calculateTotal);
  }

  void _calculateTotal() {
    final amount = double.tryParse(_amountController.text.trim());
    final rate = double.tryParse(_rateController.text.trim());
    if (amount != null && rate != null && rate > 0) {
      setState(() {
        _total = amount * rate;
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
    final rate = double.tryParse(_rateController.text.trim());
    if (amount == null || amount <= 0 || _selectedCurrency == null || rate == null || rate <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Заполните все поля корректно (значения должны быть больше 0)')),
      );
      return;
    }

    try {
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
        'rate': rate,
        'total': _total,
        'userId': user.uid, // Добавляем userId для совместимости с CashService
      });

      // Очищаем поля после успешной транзакции
      _amountController.clear();
      _rateController.clear();
      setState(() {
        _total = null;
        _selectedCurrency = null;
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
    _rateController.dispose();
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
              leading: Icon(Icons.people),
              title: Text('Пользователи'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const UsersScreen()),
                );
              },
            ),
            ListTile(
              leading: Icon(Icons.brightness_6),
              title: Text('Сменить тему'),
              onTap: () {
                showDialog(
                  context: context,
                  builder: (context) {
                    return AlertDialog(
                      title: Text('Сменить тему'),
                      content: Text('Выберите тему:'),
                      actions: [
                        TextButton(
                          onPressed: () {
                            Navigator.of(context).pop();
                            setState(() {
                              // Change to light theme
                              ThemeData theme = Theme.of(context);
                              if (theme.brightness == Brightness.dark) {
                                theme = ThemeData.light();
                              }
                              // Apply the light theme
                            });
                          },
                          child: Text('Светлая'),
                        ),
                        TextButton(
                          onPressed: () {
                            Navigator.of(context).pop();
                            setState(() {
                              // Change to dark theme
                              ThemeData theme = Theme.of(context);
                              if (theme.brightness == Brightness.light) {
                                theme = ThemeData.dark();
                              }
                              // Apply the dark theme
                            });
                          },
                          child: Text('Темная'),
                        ),
                      ],
                    );
                  },
                );
              },
            ),
            ListTile(
              leading: Icon(Icons.logout),
              title: Text('Выйти'),
              onTap: () async {
                final shouldSignOut = await showDialog<bool>(
                  context: context,
                  builder: (context) {
                    return AlertDialog(
                      title: Text('Подтверждение'),
                      content: Text('Вы уверены, что хотите выйти из аккаунта?'),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.of(context).pop(false),
                          child: Text('Отмена'),
                        ),
                        TextButton(
                          onPressed: () => Navigator.of(context).pop(true),
                          child: Text('Выйти'),
                        ),
                      ],
                    );
                  },
                );

                if (shouldSignOut == true) {
                  _authService.signOut().then((_) {
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(builder: (context) => const LoginScreen()),
                    );
                  });
                }
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
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snapshot.hasError) {
                    return Center(
                      child: Column(
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
                  if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                    return const Center(child: Text('Нет доступных валют'));
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
                            final rate = (doc.data()!['rate'] as num?)?.toDouble();
                            setState(() {
                              _rateController.text = rate?.toString() ?? '';
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
                  controller: _rateController,
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