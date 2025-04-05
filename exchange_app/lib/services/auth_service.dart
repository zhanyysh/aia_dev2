// lib/services/auth_service.dart
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<UserCredential> signUp(String email, String password, String username) async {
    try {
      print('Начало регистрации пользователя: $email');
      // Создаём вторичный экземпляр FirebaseAuth, чтобы не затрагивать текущую сессию
      FirebaseAuth secondaryAuth = FirebaseAuth.instanceFor(app: FirebaseAuth.instance.app);
      UserCredential userCredential = await secondaryAuth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      User? user = userCredential.user;
      if (user != null) {
        print('Пользователь зарегистрирован, UID: ${user.uid}');
        await user.updateDisplayName(username);
        await user.reload();
        try {
          await _firestore.collection('users').doc(user.uid).set({
            'uid': user.uid,
            'email': email,
            'username': username,
            'isSuperAdmin': false,
          });
          print('Данные пользователя успешно записаны в Firestore: ${user.uid}');
        } catch (firestoreError) {
          print('Ошибка записи в Firestore: $firestoreError');
        }
      }
      // Выходим из вторичной сессии, чтобы не оставлять её активной
      await secondaryAuth.signOut();
      return userCredential;
    } catch (e) {
      print('Ошибка регистрации: $e');
      rethrow;
    }
  }

  Future<User?> signIn(String email, String password) async {
    try {
      print('Начало входа пользователя: $email');
      UserCredential userCredential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      print('Пользователь вошел, UID: ${userCredential.user?.uid}');
      return userCredential.user;
    } catch (e) {
      print('Ошибка входа: $e');
      rethrow;
    }
  }

  Future<void> signOut() async {
    await _auth.signOut();
    print('Пользователь вышел');
  }

  User? getCurrentUser() {
    return _auth.currentUser;
  }

  Future<bool> isSuperAdmin() async {
    User? user = _auth.currentUser;
    if (user == null) return false;

    try {
      DocumentSnapshot doc = await _firestore.collection('users').doc(user.uid).get();
      if (doc.exists) {
        return doc['isSuperAdmin'] ?? false;
      }
      return false;
    } catch (e) {
      print('Ошибка проверки статуса суперадмина: $e');
      return false;
    }
  }
}