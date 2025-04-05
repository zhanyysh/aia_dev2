import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:exchange_app/screens/home_screen.dart';
import 'package:exchange_app/screens/login_screen.dart';
import 'package:exchange_app/screens/signup_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

void main() {
  runApp(const MyApp());
} 

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Exchange App',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: const InitializeFirebase(),
    );
  }
}

class InitializeFirebase extends StatelessWidget {
  const InitializeFirebase({super.key});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: _initializeFirebase(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (snapshot.hasError) {
          return Scaffold(
            body: Center(child: Text('Ошибка: ${snapshot.error}')),
          );
        }
        // После успешной инициализации Firebase проверяем состояние авторизации
        return StreamBuilder<User?>(
          stream: FirebaseAuth.instance.authStateChanges(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            // Если пользователь авторизован, показываем HomeScreen
            if (snapshot.hasData) {
              return const HomeScreen();
            }
            // Если пользователь не авторизован, показываем экран логина
            return MaterialApp(
              title: 'Exchange App',
              theme: ThemeData(
                primarySwatch: Colors.blue,
              ),
              initialRoute: '/login',
              routes: {
                '/login': (context) => const LoginScreen(),
                '/signup': (context) => const SignUpScreen(),
                '/main': (context) => const HomeScreen(), // Перенаправляем /main на HomeScreen
              },
            );
          },
        );
      },
    );
  }

  Future<void> _initializeFirebase() async {
    WidgetsFlutterBinding.ensureInitialized();
    if (kIsWeb) {
      // Для веб-платформы передаем FirebaseOptions
      await Firebase.initializeApp(
        options: const FirebaseOptions(
          apiKey: "AIzaSyCAmuqpWKZiwId6hQ4eGRS0z8lZmmKdhaY",
          authDomain: "exchange-3ce2d.firebaseapp.com",
          projectId: "exchange-3ce2d",
          storageBucket: "exchange-3ce2d.firebasestorage.app",
          messagingSenderId: "745484902035",
          appId: "1:745484902035:web:ea9e9b552ed7cb5974b766",
          // measurementId: "G-Q0ZRWGZCF9"
        ),
      );
    } else {
      // Для мобильных платформ (Android, iOS) используем google-services.json
      await Firebase.initializeApp();
    }
  }
}