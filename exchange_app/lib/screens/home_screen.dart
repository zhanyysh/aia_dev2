import 'package:flutter/material.dart';
import 'package:exchange_app/screens/cash_screen.dart';
import 'package:exchange_app/screens/currency_screen.dart';
import 'package:exchange_app/screens/events_screen.dart';
import 'package:exchange_app/screens/login_screen.dart';
import 'package:exchange_app/screens/main_screen.dart';
import 'package:exchange_app/services/auth_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;
  final AuthService _authService = AuthService();

  // Список экранов
  final List<Widget> _screens = [
    const MainScreen(),
    const EventsScreen(),
    const CashScreen(),
    const CurrencyScreen(),
  ];

  void _onItemTapped(int index) {
    if (index == 4) {
      // Если нажата кнопка "Выход"
      _authService.signOut().then((_) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const LoginScreen()),
        );
      });
    } else {
      setState(() {
        _selectedIndex = index;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _selectedIndex,
        children: _screens,
      ),
      bottomNavigationBar: BottomNavigationBar(
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: 'Главная',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.event),
            label: 'События',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.account_balance_wallet),
            label: 'Касса',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.settings),
            label: 'Настройки',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.logout),
            label: 'Выйти',
          ),
        ],
        currentIndex: _selectedIndex,
        selectedItemColor: Colors.blueAccent,
        unselectedItemColor: Colors.black,
        showSelectedLabels: true, // Показывать подписи для выбранного элемента
        showUnselectedLabels: true, // Показывать подписи для невыбранных элементов
        backgroundColor: Colors.grey[200],
        onTap: _onItemTapped,
      ),
    );
  }
}