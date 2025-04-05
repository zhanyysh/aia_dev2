import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:exchange_app/screens/currency_screen.dart';
import 'package:exchange_app/screens/login_screen.dart';
import 'package:exchange_app/screens/users_screen.dart';
import 'package:exchange_app/services/auth_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Create a ThemeProvider to manage theme state across the app
class ThemeProvider extends InheritedWidget {
  final ThemeMode themeMode;
  final Function(ThemeMode) updateThemeMode;

  const ThemeProvider({
    Key? key,
    required this.themeMode,
    required this.updateThemeMode,
    required Widget child,
  }) : super(key: key, child: child);

  static ThemeProvider of(BuildContext context) {
    final ThemeProvider? result = context.dependOnInheritedWidgetOfExactType<ThemeProvider>();
    assert(result != null, 'No ThemeProvider found in context');
    return result!;
  }

  @override
  bool updateShouldNotify(ThemeProvider oldWidget) {
    return themeMode != oldWidget.themeMode;
  }
}

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> with SingleTickerProviderStateMixin {
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _rateController = TextEditingController();
  String? _selectedCurrency;
  double? _total;
  bool _isSelling = true; // true = Продажа (стрелка вверх), false = Покупка (стрелка вниз)
  final AuthService _authService = AuthService();
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  
  // Add theme mode state
  ThemeMode _themeMode = ThemeMode.light;

  @override
  void initState() {
    super.initState();
    _amountController.addListener(_calculateTotal);
    _rateController.addListener(_calculateTotal);
    
    // Initialize animation controller
    _animationController = AnimationController(
      vsync: this, 
      duration: const Duration(milliseconds: 300),
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeIn)
    );
    _animationController.forward();
    
    // Load saved theme preference
    _loadThemePreference();
  }

  // Load theme preference from SharedPreferences
  Future<void> _loadThemePreference() async {
    final prefs = await SharedPreferences.getInstance();
    final isDark = prefs.getBool('isDarkTheme') ?? false;
    setState(() {
      _themeMode = isDark ? ThemeMode.dark : ThemeMode.light;
    });
  }

  // Save theme preference to SharedPreferences
  Future<void> _saveThemePreference(bool isDark) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isDarkTheme', isDark);
  }

  // Change theme and save preference
  void _changeTheme(ThemeMode mode) async {
    setState(() {
      _themeMode = mode;
    });
    await _saveThemePreference(mode == ThemeMode.dark);
  }

  void _calculateTotal() {
    final amount = double.tryParse(_amountController.text.trim());
    final rate = double.tryParse(_rateController.text.trim());
    if (amount != null && rate != null && rate > 0) {
      setState(() {
        _total = amount * rate;
      });
    } else {
      setState(() {
        _total = null;
      });
    }
  }

  Future<void> _addEvent() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Пользователь не авторизован')),
      );
      return;
    }

    final amount = double.tryParse(_amountController.text.trim());
    final rate = double.tryParse(_rateController.text.trim());
    if (amount == null || amount <= 0 || _selectedCurrency == null || rate == null || rate <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Заполните все поля корректно (значения должны быть больше 0)')),
      );
      return;
    }

    try {
      // Добавляем транзакцию в events с нужными полями
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('events')
          .add({
        'currency': _selectedCurrency,
        'date': Timestamp.now(),
        'type': _isSelling ? 'sell' : 'buy',
        'amount': amount,
        'rate': rate,
        'total': _total,
        'userId': user.uid, // Добавляем userId для совместимости с CashService
      });

      // Очищаем поля после успешной транзакции
      _amountController.clear();
      _rateController.clear();
      setState(() {
        _total = null;
        _selectedCurrency = null;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Транзакция добавлена')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ошибка: $e')),
      );
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
    _rateController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  // Helper method for creating styled input field containers
  Widget _buildInputField(
    Widget child, {
    IconData? prefixIcon,
    Color iconColor = Colors.blueAccent,
  }) {
    // Get screen width once
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallWidth = screenWidth < 360;
    
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            spreadRadius: 1,
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          if (prefixIcon != null)
            Padding(
              padding: EdgeInsets.only(left: isSmallWidth ? 8.0 : 16.0),
              child: Icon(
                prefixIcon, 
                color: iconColor,
                size: isSmallWidth ? 20 : 24,
              ),
            ),
          Expanded(child: child),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const Scaffold(
        body: Center(child: Text('Пользователь не авторизован')),
      );
    }

    // Get screen size to make layout responsive
    final screenSize = MediaQuery.of(context).size;
    final isSmallScreen = screenSize.width < 360;

    // Wrap the scaffold with ThemeProvider
    return ThemeProvider(
      themeMode: _themeMode,
      updateThemeMode: _changeTheme,
      child: Theme(
        // Apply theme based on current mode
        data: _themeMode == ThemeMode.dark 
          ? ThemeData.dark().copyWith(
              primaryColor: Colors.blueAccent,
              appBarTheme: const AppBarTheme(
                backgroundColor: Colors.blueAccent,
              ),
            )
          : ThemeData.light().copyWith(
              primaryColor: Colors.blueAccent,
              appBarTheme: const AppBarTheme(
                backgroundColor: Colors.blueAccent,
              ),
            ),
        child: Scaffold(
          appBar: AppBar(
            title: const FittedBox(
              fit: BoxFit.scaleDown,
              child: Text('Exchange-app'),
            ),
            centerTitle: true,
            backgroundColor: Colors.blueAccent,
            elevation: 0,
            actions: [
              Builder(
                builder: (context) => IconButton(
                  icon: const Icon(Icons.settings),
                  onPressed: () {
                    Scaffold.of(context).openDrawer();
                  },
                ),
              ),
            ],
          ),
          drawer: Drawer(
            elevation: 16.0,
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: _themeMode == ThemeMode.dark 
                    ? [Colors.grey.shade900, Colors.grey.shade800]
                    : [Colors.blue.shade50, Colors.white],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
              child: ListView(
                padding: EdgeInsets.zero,
                children: <Widget>[
                  DrawerHeader(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [Colors.blueAccent, Colors.blue],
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const CircleAvatar(
                          radius: 36,
                          backgroundColor: Colors.white,
                          child: Icon(Icons.account_circle, size: 60, color: Colors.blueAccent),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          user.email ?? 'Пользователь',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                          ),
                        ),
                        const Text(
                          'Меню',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                  _buildDrawerItem(
                    icon: Icons.currency_exchange,
                    title: 'Валюты',
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const CurrencyScreen()),
                      );
                    },
                  ),
                  _buildDrawerItem(
                    icon: Icons.people,
                    title: 'Пользователи',
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const UsersScreen()),
                      );
                    },
                  ),
                  _buildDrawerItem(
                    icon: Icons.brightness_6,
                    title: 'Сменить тему',
                    onTap: () {
                      showDialog(
                        context: context,
                        builder: (context) {
                          return AlertDialog(
                            title: const Text('Сменить тему'),
                            content: const Text('Выберите тему:'),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            actions: [
                              TextButton(
                                onPressed: () {
                                  Navigator.of(context).pop();
                                  _changeTheme(ThemeMode.light);
                                },
                                child: const Text('Светлая'),
                              ),
                              ElevatedButton(
                                onPressed: () {
                                  Navigator.of(context).pop();
                                  _changeTheme(ThemeMode.dark);
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.blueAccent,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                                child: const Text('Темная'),
                              ),
                            ],
                          );
                        },
                      );
                    },
                  ),
                  const Divider(),
                  _buildDrawerItem(
                    icon: Icons.logout,
                    title: 'Выйти',
                    onTap: () async {
                      final shouldSignOut = await showDialog<bool>(
                        context: context,
                        builder: (context) {
                          return AlertDialog(
                            title: const Text('Подтверждение'),
                            content: const Text('Вы уверены, что хотите выйти из аккаунта?'),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.of(context).pop(false),
                                child: const Text('Отмена'),
                              ),
                              ElevatedButton(
                                onPressed: () => Navigator.of(context).pop(true),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.red,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                                child: const Text('Выйти'),
                              ),
                            ],
                          );
                        },
                      );

                      if (shouldSignOut == true) {
                        _authService.signOut().then((_) {
                          Navigator.pushReplacement(
                            context,
                            MaterialPageRoute(builder: (context) => const LoginScreen()),
                          );
                        });
                      }
                    },
                  ),
                ],
              ),
            ),
          ),
          body: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: _themeMode == ThemeMode.dark 
                  ? [Colors.grey.shade900, Colors.grey.shade800, Colors.grey.shade900]
                  : [Colors.blue.shade50, Colors.white, Colors.blue.shade50],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: SafeArea(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  child: Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: screenSize.width * 0.05, // Responsive padding
                      vertical: 24.0,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Header text with FittedBox to prevent overflow
                        const FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            'Новая транзакция',
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: Colors.blueAccent,
                            ),
                          ),
                        ),
                        const SizedBox(height: 6),
                        // Remove Flexible here and just use Text with maxLines
                        Text(
                          'Заполните данные для создания транзакции',
                          style: TextStyle(
                            fontSize: isSmallScreen ? 12 : 14,
                            color: Colors.grey,
                          ),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 2,
                        ),
                        const SizedBox(height: 24),
                        
                        // Transaction type selector
                        Card(
                          elevation: 4,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Тип транзакции',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 16),
                                // Using LayoutBuilder to make transaction type buttons responsive
                                LayoutBuilder(
                                  builder: (context, constraints) {
                                    return Row(
                                      children: [
                                        Expanded(
                                          child: GestureDetector(
                                            onTap: () {
                                              setState(() {
                                                _isSelling = true;
                                              });
                                            },
                                            child: AnimatedContainer(
                                              duration: const Duration(milliseconds: 300),
                                              height: constraints.maxWidth < 300 ? 70 : 90,
                                              decoration: BoxDecoration(
                                                color: _isSelling 
                                                    ? Colors.blueAccent.withOpacity(0.2)
                                                    : Colors.grey.withOpacity(0.1),
                                                borderRadius: BorderRadius.circular(12),
                                                border: Border.all(
                                                  color: _isSelling 
                                                      ? Colors.blueAccent
                                                      : Colors.transparent,
                                                  width: 2,
                                                ),
                                              ),
                                              child: Column(
                                                mainAxisAlignment: MainAxisAlignment.center,
                                                children: [
                                                  Icon(
                                                    Icons.arrow_upward_rounded,
                                                    color: _isSelling ? Colors.blueAccent : Colors.grey,
                                                    size: constraints.maxWidth < 300 ? 24 : 32,
                                                  ),
                                                  const SizedBox(height: 8),
                                                  Text(
                                                    'Продажа',
                                                    style: TextStyle(
                                                      color: _isSelling ? Colors.blueAccent : Colors.grey,
                                                      fontWeight: _isSelling ? FontWeight.bold : FontWeight.normal,
                                                      fontSize: constraints.maxWidth < 300 ? 12 : 14,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 16),
                                        Expanded(
                                          child: GestureDetector(
                                            onTap: () {
                                              setState(() {
                                                _isSelling = false;
                                              });
                                            },
                                            child: AnimatedContainer(
                                              duration: const Duration(milliseconds: 300),
                                              height: constraints.maxWidth < 300 ? 70 : 90,
                                              decoration: BoxDecoration(
                                                color: !_isSelling 
                                                    ? Colors.blueAccent.withOpacity(0.2)
                                                    : Colors.grey.withOpacity(0.1),
                                                borderRadius: BorderRadius.circular(12),
                                                border: Border.all(
                                                  color: !_isSelling 
                                                      ? Colors.blueAccent
                                                      : Colors.transparent,
                                                  width: 2,
                                                ),
                                              ),
                                              child: Column(
                                                mainAxisAlignment: MainAxisAlignment.center,
                                                children: [
                                                  Icon(
                                                    Icons.arrow_downward_rounded,
                                                    color: !_isSelling ? Colors.blueAccent : Colors.grey,
                                                    size: constraints.maxWidth < 300 ? 24 : 32,
                                                  ),
                                                  const SizedBox(height: 8),
                                                  Text(
                                                    'Покупка',
                                                    style: TextStyle(
                                                      color: !_isSelling ? Colors.blueAccent : Colors.grey,
                                                      fontWeight: !_isSelling ? FontWeight.bold : FontWeight.normal,
                                                      fontSize: constraints.maxWidth < 300 ? 12 : 14,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    );
                                  },
                                ),
                              ],
                            ),
                          ),
                        ),
                        
                        const SizedBox(height: 24),
                        
                        // Currency selection and form fields
                        Card(
                          elevation: 4,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Padding(
                            padding: EdgeInsets.all(isSmallScreen ? 12.0 : 20.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Детали транзакции',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 20),
                                StreamBuilder<QuerySnapshot>(
                                  stream: FirebaseFirestore.instance
                                      .collection('users')
                                      .doc(user.uid)
                                      .collection('currencies')
                                      .snapshots(),
                                  builder: (context, snapshot) {
                                    if (snapshot.connectionState == ConnectionState.waiting) {
                                      return const Center(
                                        child: Padding(
                                          padding: EdgeInsets.all(16.0),
                                          child: CircularProgressIndicator(),
                                        ),
                                      );
                                    }
                                    if (snapshot.hasError) {
                                      return Center(
                                        child: Column(
                                          children: [
                                            Text(
                                              'Ошибка: ${snapshot.error.toString()}',
                                              style: const TextStyle(color: Colors.red),
                                              overflow: TextOverflow.ellipsis,
                                              maxLines: 2,
                                            ),
                                            const SizedBox(height: 16),
                                            ElevatedButton.icon(
                                              onPressed: () {
                                                setState(() {}); // Перезапускаем StreamBuilder
                                              },
                                              icon: const Icon(Icons.refresh),
                                              label: const Text('Повторить'),
                                              style: ElevatedButton.styleFrom(
                                                backgroundColor: Colors.blueAccent,
                                                shape: RoundedRectangleBorder(
                                                  borderRadius: BorderRadius.circular(8),
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      );
                                    }
                                    if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                                      return const Padding(
                                        padding: EdgeInsets.all(16.0),
                                        child: Center(
                                          child: Text(
                                            'Нет доступных валют',
                                            style: TextStyle(
                                              fontSize: 16,
                                              fontStyle: FontStyle.italic,
                                            ),
                                          ),
                                        ),
                                      );
                                    }

                                    final currencies = snapshot.data!.docs;
                                    final currencyNames = currencies.map((doc) => doc.id).toList();

                                    return _buildInputField(
                                      DropdownButtonFormField<String>(
                                        decoration: InputDecoration(
                                          labelText: 'Валюта',
                                          border: InputBorder.none,
                                          contentPadding: EdgeInsets.symmetric(
                                            horizontal: isSmallScreen ? 8 : 16,
                                            vertical: isSmallScreen ? 8 : 16,
                                          ),
                                        ),
                                        value: _selectedCurrency,
                                        isExpanded: true,
                                        icon: const Icon(Icons.arrow_drop_down_circle, color: Colors.blueAccent),
                                        items: currencyNames.map((name) {
                                          return DropdownMenuItem<String>(
                                            value: name,
                                            child: Text(
                                              name,
                                              style: TextStyle(fontSize: isSmallScreen ? 13 : 14),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          );
                                        }).toList(),
                                        onChanged: (value) async {
                                          setState(() {
                                            _selectedCurrency = value;
                                          });
                                          if (value != null) {
                                            final doc = await FirebaseFirestore.instance
                                                .collection('users')
                                                .doc(user.uid)
                                                .collection('currencies')
                                                .doc(value)
                                                .get();
                                            if (doc.exists) {
                                              final rate = (doc.data()!['rate'] as num?)?.toDouble();
                                              setState(() {
                                                _rateController.text = rate?.toString() ?? '';
                                              });
                                              _calculateTotal();
                                            }
                                          }
                                        },
                                      ),
                                      prefixIcon: Icons.currency_exchange,
                                    );
                                  },
                                ),
                                
                                _buildInputField(
                                  TextField(
                                    controller: _amountController,
                                    decoration: InputDecoration(
                                      labelText: 'Количество',
                                      border: InputBorder.none,
                                      contentPadding: EdgeInsets.symmetric(
                                        horizontal: isSmallScreen ? 8 : 16,
                                        vertical: isSmallScreen ? 8 : 16,
                                      ),
                                    ),
                                    keyboardType: TextInputType.number,
                                    style: TextStyle(fontSize: isSmallScreen ? 14 : 16),
                                  ),
                                  prefixIcon: Icons.numbers,
                                ),
                                
                                _buildInputField(
                                  TextField(
                                    controller: _rateController,
                                    decoration: InputDecoration(
                                      labelText: 'Курс',
                                      border: InputBorder.none,
                                      contentPadding: EdgeInsets.symmetric(
                                        horizontal: isSmallScreen ? 8 : 16,
                                        vertical: isSmallScreen ? 8 : 16,
                                      ),
                                    ),
                                    keyboardType: TextInputType.number,
                                    style: TextStyle(fontSize: isSmallScreen ? 14 : 16),
                                  ),
                                  prefixIcon: Icons.trending_up,
                                ),
                                
                                // Total amount display with responsiveness
                                Container(
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: Colors.blueAccent.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: Colors.blueAccent.withOpacity(0.3),
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(Icons.calculate, color: Colors.blueAccent),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            const Text(
                                              'Итоговая сумма',
                                              style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                                color: Colors.blueAccent,
                                              ),
                                            ),
                                            const SizedBox(height: 4),
                                            // Using FittedBox to ensure the total fits without overflow
                                            FittedBox(
                                              fit: BoxFit.scaleDown,
                                              alignment: Alignment.centerLeft,
                                              child: Text(
                                                '${_total?.toStringAsFixed(2) ?? "0.00"} ${ "Сом"}',
                                                style: TextStyle(
                                                  fontSize: isSmallScreen ? 18 : 20,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        
                        const SizedBox(height: 32),
                        
                        // Submit button - making it adaptable to screen size
                        SizedBox(
                          width: double.infinity,
                          height: isSmallScreen ? 48 : 56,
                          child: ElevatedButton(
                            onPressed: () {
                              _addEvent();
                            },
                            style: ElevatedButton.styleFrom(
                              padding: EdgeInsets.zero,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                              elevation: 8,
                              shadowColor: _themeMode == ThemeMode.dark 
                                ? const Color(0xFF9C27B0).withOpacity(0.6)
                                : const Color(0xFFB71C1C).withOpacity(0.6),
                            ).copyWith(
                              backgroundColor: MaterialStateProperty.all(Colors.transparent),
                              overlayColor: MaterialStateProperty.resolveWith<Color?>(
                                (Set<MaterialState> states) {
                                  if (states.contains(MaterialState.pressed))
                                    return _themeMode == ThemeMode.dark
                                      ? Colors.deepPurple.withOpacity(0.2)
                                      : Colors.amber.withOpacity(0.1);
                                  return null;
                                },
                              ),
                            ),
                            child: Ink(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: _themeMode == ThemeMode.dark
                                    // Dark theme: Rich purple to deep blue gradient with shimmer effect
                                    ? [
                                        const Color(0xFF9C27B0), 
                                        const Color(0xFF673AB7),
                                        const Color(0xFF3F51B5), 
                                        const Color(0xFF2196F3)
                                      ]
                                    // Light theme: Premium gold to deep red with more vibrant steps
                                    : [
                                        const Color(0xFFFFC107), 
                                        const Color(0xFFFF9800),
                                        const Color(0xFFFF5722), 
                                        const Color(0xFFB71C1C)
                                      ],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  stops: const [0.0, 0.3, 0.7, 1.0], // Smooth color distribution
                                ),
                                borderRadius: BorderRadius.circular(16),
                                boxShadow: [
                                  BoxShadow(
                                    color: _themeMode == ThemeMode.dark
                                      ? const Color(0xFF673AB7).withOpacity(0.5)
                                      : const Color(0xFFB71C1C).withOpacity(0.3),
                                    offset: const Offset(0, 4),
                                    blurRadius: 12,
                                    spreadRadius: 1,
                                  ),
                                ],
                              ),
                              child: Container(
                                alignment: Alignment.center,
                                child: Text(
                                  'Выполнить транзакцию',
                                  style: TextStyle(
                                    fontSize: isSmallScreen ? 16 : 18,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                    shadows: [
                                      Shadow(
                                        offset: const Offset(1, 1),
                                        blurRadius: 2,
                                        color: Colors.black.withOpacity(0.3),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
  
  // Helper method for drawer items
  Widget _buildDrawerItem({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Icon(icon, color: Colors.blueAccent),
      title: Text(
        title,
        style: const TextStyle(
          fontSize: 16,
        ),
      ),
      onTap: onTap,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      tileColor: Colors.transparent,
      hoverColor: Colors.blue.shade50,
    );
  }
}