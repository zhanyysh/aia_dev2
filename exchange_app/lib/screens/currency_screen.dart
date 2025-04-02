import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:exchange_app/services/auth_service.dart';

class CurrencyScreen extends StatefulWidget {
  const CurrencyScreen({super.key});

  @override
  State<CurrencyScreen> createState() => _CurrencyScreenState();
}

class _CurrencyScreenState extends State<CurrencyScreen> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _rateController = TextEditingController();
  final TextEditingController _symbolController = TextEditingController();
  final AuthService _authService = AuthService();

  Future<bool> _isSuperAdmin() async {
    final user = _authService.getCurrentUser();
    if (user == null) return false;
    final userDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
    return userDoc.data()?['isSuperAdmin'] ?? false;
  }

  Future<void> _addCurrency() async {
    final name = _nameController.text.trim();
    final rate = double.tryParse(_rateController.text.trim());
    final symbol = _symbolController.text.trim();

    if (name.isEmpty || rate == null || symbol.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Заполните все поля')),
      );
      return;
    }

    try {
      await FirebaseFirestore.instance.collection('currencies').doc(name).set({
        'name': name,
        'rate': rate,
        'symbol': symbol,
      });
      _nameController.clear();
      _rateController.clear();
      _symbolController.clear();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Валюта добавлена')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ошибка: $e')),
      );
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _rateController.dispose();
    _symbolController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Валюты'),
        backgroundColor: Colors.blueAccent,
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.blue.shade100, Colors.white],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Column(
          children: [
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
                          controller: _nameController,
                          decoration: InputDecoration(
                            labelText: 'Название валюты (например, USD)',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            filled: true,
                            fillColor: Colors.white.withOpacity(0.8),
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: _rateController,
                          decoration: InputDecoration(
                            labelText: 'Курс',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            filled: true,
                            fillColor: Colors.white.withOpacity(0.8),
                          ),
                          keyboardType: TextInputType.number,
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: _symbolController,
                          decoration: InputDecoration(
                            labelText: 'Символ (например)',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            filled: true,
                            fillColor: Colors.white.withOpacity(0.8),
                          ),
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: _addCurrency,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blueAccent,
                            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Text(
                            'Добавить валюту',
                            style: TextStyle(fontSize: 16),
                          ),
                        ),
                      ],
                    ),
                  );
                }
                return const SizedBox.shrink();
              },
            ),
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance.collection('currencies').snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snapshot.hasError) {
                    return Center(child: Text('Ошибка: ${snapshot.error}'));
                  }
                  if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                    return const Center(child: Text('Нет доступных валют'));
                  }

                  final currencies = snapshot.data!.docs;

                  return ListView.builder(
                    itemCount: currencies.length,
                    itemBuilder: (context, index) {
                      final currency = currencies[index].data() as Map<String, dynamic>;
                      return ListTile(
                        leading: Text(currency['symbol'] ?? ''),
                        title: Text(currency['name'] ?? 'Неизвестная валюта'),
                        subtitle: Text('Курс: ${currency['rate']?.toString() ?? 'N/A'}'),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}