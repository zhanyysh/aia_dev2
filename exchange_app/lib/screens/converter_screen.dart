import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ConverterScreen extends StatefulWidget {
  const ConverterScreen({super.key});

  @override
  State<ConverterScreen> createState() => _ConverterScreenState();
}

class _ConverterScreenState extends State<ConverterScreen> {
  final TextEditingController _amountController = TextEditingController();
  String? _fromCurrency;
  String? _toCurrency;
  double? _result;

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _convert() async {
    final amount = double.tryParse(_amountController.text.trim());
    if (amount == null || _fromCurrency == null || _toCurrency == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Заполните все поля')),
      );
      return;
    }

    try {
      final fromDoc = await FirebaseFirestore.instance.collection('currencies').doc(_fromCurrency).get();
      final toDoc = await FirebaseFirestore.instance.collection('currencies').doc(_toCurrency).get();

      if (!fromDoc.exists || !toDoc.exists) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Валюта не найдена')),
        );
        return;
      }

      final fromRate = (fromDoc.data()!['rate'] as num).toDouble();
      final toRate = (toDoc.data()!['rate'] as num).toDouble();

      setState(() {
        _result = (amount / fromRate) * toRate;
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ошибка: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Конвертер валют'),
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
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              TextField(
                controller: _amountController,
                decoration: InputDecoration(
                  labelText: 'Сумма',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  filled: true,
                  fillColor: Colors.white.withOpacity(0.8),
                ),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 16),
              StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance.collection('currencies').snapshots(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) {
                    return const CircularProgressIndicator();
                  }
                  final currencies = snapshot.data!.docs;
                  final currencyNames = currencies.map((doc) => doc.id).toList();

                  return Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          decoration: InputDecoration(
                            labelText: 'Из валюты',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            filled: true,
                            fillColor: Colors.white.withOpacity(0.8),
                          ),
                          value: _fromCurrency,
                          items: currencyNames.map((name) {
                            return DropdownMenuItem<String>(
                              value: name,
                              child: Text(name),
                            );
                          }).toList(),
                          onChanged: (value) {
                            setState(() {
                              _fromCurrency = value;
                              _result = null;
                            });
                          },
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          decoration: InputDecoration(
                            labelText: 'В валюту',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            filled: true,
                            fillColor: Colors.white.withOpacity(0.8),
                          ),
                          value: _toCurrency,
                          items: currencyNames.map((name) {
                            return DropdownMenuItem<String>(
                              value: name,
                              child: Text(name),
                            );
                          }).toList(),
                          onChanged: (value) {
                            setState(() {
                              _toCurrency = value;
                              _result = null;
                            });
                          },
                        ),
                      ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _convert,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blueAccent,
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'Конвертировать',
                  style: TextStyle(fontSize: 16),
                ),
              ),
              const SizedBox(height: 16),
              if (_result != null)
                Text(
                  'Результат: ${_result!.toStringAsFixed(2)} $_toCurrency',
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.blueAccent),
                ),
            ],
          ),
        ),
      ),
    );
  }
}