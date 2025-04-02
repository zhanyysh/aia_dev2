import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:exchange_app/services/auth_service.dart';
import 'package:exchange_app/widgets/app_drawer.dart';

class EventsScreen extends StatefulWidget {
  const EventsScreen({super.key});

  @override
  State<EventsScreen> createState() => _EventsScreenState();
}

class _EventsScreenState extends State<EventsScreen> {
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _currencyController = TextEditingController();
  final AuthService _authService = AuthService();

  Future<bool> _isSuperAdmin() async {
    final user = _authService.getCurrentUser()!;
    final userDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
    return userDoc.data()?['isSuperAdmin'] ?? false;
  }

  Future<void> _addEvent() async {
    final user = FirebaseAuth.instance.currentUser!;
    final title = _titleController.text.trim();
    final description = _descriptionController.text.trim();
    final currency = _currencyController.text.trim();

    if (title.isEmpty || description.isEmpty || currency.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Заполните все поля')),
      );
      return;
    }

    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('events')
          .add({
        'title': title,
        'description': description,
        'currency': currency,
        'date': Timestamp.now(),
        'type': 'custom',
      });
      _titleController.clear();
      _descriptionController.clear();
      _currencyController.clear();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Событие добавлено')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ошибка: $e')),
      );
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _currencyController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser!;
    return Scaffold(
      appBar: AppBar(
        title: const Text('События'),
        backgroundColor: Colors.blueAccent,
        elevation: 0,
      ),
      drawer: AppDrawer(currentRoute: 'events', authService: _authService),
      body: Column(
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
                        controller: _titleController,
                        decoration: const InputDecoration(
                          labelText: 'Название события',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _descriptionController,
                        decoration: const InputDecoration(
                          labelText: 'Описание',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _currencyController,
                        decoration: const InputDecoration(
                          labelText: 'Валюта (например, USD)',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _addEvent,
                        child: const Text('Добавить событие'),
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
              stream: FirebaseFirestore.instance
                  .collection('users')
                  .doc(user.uid)
                  .collection('events')
                  .orderBy('date', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(child: Text('Ошибка: ${snapshot.error}'));
                }
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const Center(child: Text('Нет доступных событий'));
                }

                final events = snapshot.data!.docs;

                return ListView.builder(
                  itemCount: events.length,
                  itemBuilder: (context, index) {
                    final event = events[index].data() as Map<String, dynamic>;
                    final type = event['type'] ?? 'custom';
                    return ListTile(
                      leading: type == 'sell'
                          ? const Icon(Icons.arrow_upward, color: Colors.red)
                          : type == 'buy'
                              ? const Icon(Icons.arrow_downward, color: Colors.green)
                              : const Icon(Icons.event),
                      title: Text(event['title'] ?? 'Без названия'),
                      subtitle: Text(event['description'] ?? 'Без описания'),
                      trailing: Text(event['currency'] ?? ''),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}