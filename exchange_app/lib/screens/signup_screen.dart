// lib/screens/signup_screen.dart
import 'package:flutter/material.dart';
import 'package:exchange_app/services/auth_service.dart';
import 'package:exchange_app/screens/login_screen.dart';
import 'package:exchange_app/widgets/app_drawer.dart'; // Добавляем импорт для AppDrawer

class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key});

  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _usernameController = TextEditingController();
  final AuthService _authService = AuthService();
  bool _isLoading = false;
  String? _emailError;
  String? _passwordError;
  String? _usernameError;

  Future<void> _handleSignUp() async {
    setState(() {
      _emailError = null;
      _passwordError = null;
      _usernameError = null;
      _isLoading = true;
    });

    String email = _emailController.text.trim();
    String password = _passwordController.text.trim();
    String username = _usernameController.text.trim();

    bool isValid = true;
    if (username.isEmpty) {
      setState(() {
        _usernameError = 'Введите имя пользователя';
      });
      isValid = false;
    }
    if (!RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(email)) {
      setState(() {
        _emailError = 'Введите корректный email';
      });
      isValid = false;
    }
    if (password.length < 6) {
      setState(() {
        _passwordError = 'Пароль должен быть не менее 6 символов';
      });
      isValid = false;
    }

    if (!isValid) {
      setState(() {
        _isLoading = false;
      });
      return;
    }

    try {
      print('Начало регистрации: $email, $username');
      await _authService.signUp(email, password, username);
      print('Регистрация успешна, переход на /login');
      setState(() {
        _isLoading = false;
      });
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => const LoginScreen()),
        (Route<dynamic> route) => false,
      );
    } catch (e) {
      print('Ошибка регистрации: $e');
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ошибка регистрации: $e')),
      );
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _usernameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Регистрация'),
        backgroundColor: Colors.blueAccent,
      ),
      drawer: AppDrawer( // Добавляем боковое меню
        currentRoute: 'signup',
        authService: _authService,
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.blue.shade100, Colors.white],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              TextField(
                controller: _usernameController,
                decoration: InputDecoration(
                  labelText: 'Имя пользователя',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  filled: true,
                  fillColor: Colors.white.withOpacity(0.8),
                  errorText: _usernameError,
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _emailController,
                decoration: InputDecoration(
                  labelText: 'Email',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  filled: true,
                  fillColor: Colors.white.withOpacity(0.8),
                  errorText: _emailError,
                ),
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _passwordController,
                decoration: InputDecoration(
                  labelText: 'Пароль',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  filled: true,
                  fillColor: Colors.white.withOpacity(0.8),
                  errorText: _passwordError,
                ),
                obscureText: true,
              ),
              const SizedBox(height: 24),
              _isLoading
                  ? const CircularProgressIndicator()
                  : ElevatedButton(
                      onPressed: _handleSignUp,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blueAccent,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 32,
                          vertical: 16,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'Зарегистрироваться',
                        style: TextStyle(fontSize: 16),
                      ),
                    ),
              const SizedBox(height: 16),
              TextButton(
                onPressed: () {
                  Navigator.pushNamed(context, '/login');
                },
                child: const Text(
                  'Уже есть аккаунт? Войдите',
                  style: TextStyle(color: Colors.blueAccent),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}