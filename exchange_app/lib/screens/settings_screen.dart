// lib/screens/settings_screen.dart
import 'package:flutter/material.dart';
import 'package:exchange_app/services/auth_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';


class SettingsScreen extends StatefulWidget {
  final AuthService authService;

  const SettingsScreen({super.key, required this.authService});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final TextEditingController _currencyCodeController = TextEditingController();
  final TextEditingController _newUserEmailController = TextEditingController();
  final TextEditingController _newUserPasswordController = TextEditingController();
  final TextEditingController _newUserUsernameController = TextEditingController();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<bool> _isSuperAdmin() async {
    final user = widget.authService.getCurrentUser();
    if (user == null) return false;
    final userDoc = await _firestore.collection('users').doc(user.uid).get();
    return userDoc.data()?['isSuperAdmin'] ?? false;
  }

  Future<void> _addCurrency() async {
    final currencyCode = _currencyCodeController.text.trim();

    if (currencyCode.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Введите код валюты')),
      );
      return;
    }

    try {
      await _firestore.collection('currencies').doc(currencyCode).set({
        'code': currencyCode,
        'createdAt': Timestamp.now(),
      });
      _currencyCodeController.clear();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Валюта добавлена')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ошибка: $e')),
      );
    }
  }

  Future<void> _addUser() async {
    final email = _newUserEmailController.text.trim();
    final password = _newUserPasswordController.text.trim();
    final username = _newUserUsernameController.text.trim();

    if (email.isEmpty || password.isEmpty || username.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Заполните все поля')),
      );
      return;
    }

    try {
      _newUserEmailController.clear();
      _newUserPasswordController.clear();
      _newUserUsernameController.clear();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Пользователь добавлен')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ошибка: $e')),
      );
    }
  }

  @override
  void dispose() {
    _currencyCodeController.dispose();
    _newUserEmailController.dispose();
    _newUserPasswordController.dispose();
    _newUserUsernameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = widget.authService.getCurrentUser();
    return Scaffold(
      appBar: AppBar(
        title: const Text('Настройки'),
        backgroundColor: Colors.blueAccent,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Пользователь: ${user?.displayName ?? "Неизвестно"}'),
              const SizedBox(height: 8),
              Text('Email: ${user?.email ?? "Неизвестно"}'),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () {
                  Navigator.pushNamed(context, '/currencies');
                },
                child: const Text('Управление валютами'),
              ),
              const SizedBox(height: 20),
              FutureBuilder<bool>(
                future: _isSuperAdmin(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snapshot.hasData && snapshot.data == true) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Добавить валюту',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: _currencyCodeController,
                          decoration: const InputDecoration(
                            labelText: 'Код валюты (например, USD)',
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: _addCurrency,
                          child: const Text('Добавить валюту'),
                        ),
                        const SizedBox(height: 20),
                        const Text(
                          'Добавить пользователя',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: _newUserEmailController,
                          decoration: const InputDecoration(
                            labelText: 'Email нового пользователя',
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: _newUserPasswordController,
                          decoration: const InputDecoration(
                            labelText: 'Пароль нового пользователя',
                            border: OutlineInputBorder(),
                          ),
                          obscureText: true,
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: _newUserUsernameController,
                          decoration: const InputDecoration(
                            labelText: 'Имя нового пользователя',
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: _addUser,
                          child: const Text('Добавить пользователя'),
                        ),
                      ],
                    );
                  }
                  return const SizedBox.shrink();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}