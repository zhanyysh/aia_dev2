// lib/widgets/app_drawer.dart
import 'package:flutter/material.dart';
import 'package:exchange_app/screens/cash_screen.dart';
import 'package:exchange_app/screens/currency_screen.dart';
import 'package:exchange_app/screens/events_screen.dart';
import 'package:exchange_app/screens/login_screen.dart';
import 'package:exchange_app/screens/main_screen.dart';// Импорт уже есть
import 'package:exchange_app/services/auth_service.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AppDrawer extends StatelessWidget {
  final String currentRoute;
  final AuthService authService;

  const AppDrawer({
    super.key,
    required this.currentRoute,
    required this.authService,
  });

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          const DrawerHeader(
            decoration: BoxDecoration(color: Colors.blue),
            child: Text('Меню', style: TextStyle(color: Colors.white, fontSize: 24)),
          ),
          ListTile(
            title: const Text('Главная'),
            selected: currentRoute == 'main',
            onTap: () {
              if (currentRoute != 'main') {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (context) => const MainScreen()),
                );
              } else {
                Navigator.pop(context);
              }
            },
          ),
          ListTile(
            title: const Text('Касса'),
            selected: currentRoute == 'cash',
            onTap: () async {
              User? user = authService.getCurrentUser();
              if (user == null) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Пожалуйста, войдите в систему')),
                );
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (context) => const LoginScreen()),
                );
              } else {
                if (currentRoute != 'cash') {
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(builder: (context) => const CashScreen()),
                  );
                } else {
                  Navigator.pop(context);
                }
              }
            },
          ),
          ListTile(
            title: const Text('Валюты'),
            selected: currentRoute == 'currencies',
            onTap: () {
              if (currentRoute != 'currencies') {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (context) => const CurrencyScreen()),
                );
              } else {
                Navigator.pop(context);
              }
            },
          ),
          ListTile(
            title: const Text('События'),
            selected: currentRoute == 'events',
            onTap: () {
              if (currentRoute != 'events') {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (context) => const EventsScreen()),
                );
              } else {
                Navigator.pop(context);
              }
            },
          ),
          ListTile(
            title: const Text('Вход'),
            selected: currentRoute == 'login',
            onTap: () {
              if (currentRoute != 'login') {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (context) => const LoginScreen()),
                );
              } else {
                Navigator.pop(context);
              }
            },
          ),
          ListTile(
            title: const Text('Выход'),
            onTap: () async {
              await authService.signOut();
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (context) => const LoginScreen()),
              );
            },
          ),
        ],
      ),
    );
  }
}