import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:exchange_app/screens/home_screen.dart';
import 'package:exchange_app/screens/login_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await _initializeFirebase();
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
      home: StreamBuilder<User?>(
        stream: FirebaseAuth.instance.authStateChanges(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }
          
          // If user is logged in, show HomeScreen, otherwise show LoginScreen
          return snapshot.hasData ? const HomeScreen() : const LoginScreen();
        },
      ),
    );
  }
}

Future<void> _initializeFirebase() async {
  if (kIsWeb) {
    await Firebase.initializeApp(
      options: const FirebaseOptions(
        apiKey: "AIzaSyCAmuqpWKZiwId6hQ4eGRS0z8lZmmKdhaY",
        authDomain: "exchange-3ce2d.firebaseapp.com",
        projectId: "exchange-3ce2d",
        storageBucket: "exchange-3ce2d.firebasestorage.app",
        messagingSenderId: "745484902035",
        appId: "1:745484902035:web:ea9e9b552ed7cb5974b766",
      ),
    );
  } else {
    await Firebase.initializeApp();
  }
}