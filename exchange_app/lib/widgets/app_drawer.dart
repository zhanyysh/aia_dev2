import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:exchange_app/screens/main_screen.dart';
import 'package:exchange_app/screens/currency_screen.dart';
import 'package:exchange_app/screens/events_screen.dart';
import 'package:exchange_app/services/auth_service.dart';

class AppDrawer extends StatelessWidget {
  final String currentRoute;
  final AuthService authService;

  const AppDrawer({super.key, required this.currentRoute, required this.authService});
  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          DrawerHeader(
            decoration: const BoxDecoration(
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
            leading: const Icon(Icons.home),
            title: const Text('Главная'),
            onTap: () {
              if (currentRoute != 'main') {
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(builder: (context) => const MainScreen()),
                  (Route<dynamic> route) => false,
                );
              } else {
                Navigator.pop(context);
              }
            },
          ),
          ListTile(
            leading: const Icon(Icons.monetization_on),
            title: const Text('Валюты'),
            onTap: () {
              if (currentRoute != 'currencies') {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const CurrencyScreen()),
                );
              } else {
                Navigator.pop(context);
              }
            },
          ),
          ListTile(
            leading: const Icon(Icons.event),
            title: const Text('События'),
            onTap: () {
              if (currentRoute != 'events') {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const EventsScreen()),
                );
              } else {
                Navigator.pop(context);
              }
            },
          ),
          ListTile(
            leading: const Icon(Icons.logout),
            title: const Text('Выйти'),
            onTap: () async {
              await FirebaseAuth.instance.signOut();
              Navigator.pushNamedAndRemoveUntil(
                context,
                '/login',
                (Route<dynamic> route) => false,
              );
            },
          ),
        ],
      ),
    );
  }
}