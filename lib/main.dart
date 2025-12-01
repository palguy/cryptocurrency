import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:hive_flutter/hive_flutter.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

// --- Global Objects ---
final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();

// --- Main Function ---
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter();
  await Hive.openBox('tracked_coins');
  await Hive.openBox('portfolio');
  await Hive.openBox('alerts');

  // Initialize notifications
  const AndroidInitializationSettings initializationSettingsAndroid =
      AndroidInitializationSettings('@mipmap/ic_launcher');
  const InitializationSettings initializationSettings = InitializationSettings(
    android: initializationSettingsAndroid,
  );
  await flutterLocalNotificationsPlugin.initialize(initializationSettings);

  runApp(const CryptoApp());
}

// --- App Root ---
class CryptoApp extends StatelessWidget {
  const CryptoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Crypto Tracker',
      theme: ThemeData.dark().copyWith(
        primaryColor: Colors.amber,
        scaffoldBackgroundColor: const Color(0xFF1A1A1A),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF2A2A2A),
          elevation: 0,
        ),
        bottomNavigationBarTheme: const BottomNavigationBarThemeData(
          backgroundColor: Color(0xFF2A2A2A),
          selectedItemColor: Colors.amber,
          unselectedItemColor: Colors.grey,
        ),
      ),
      home: const MainScreen(),
    );
  }
}

// --- Main Navigation Screen ---
class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _selectedIndex = 0;

  static final List<Widget> _widgetOptions = <Widget>[
    const CryptoListScreen(),
    const PortfolioScreen(),
    const AlertsScreen(),
    const CalculatorScreen(),
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(child: _widgetOptions.elementAt(_selectedIndex)),
      bottomNavigationBar: BottomNavigationBar(
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(icon: Icon(Icons.list), label: 'العملات'),
          BottomNavigationBarItem(
            icon: Icon(Icons.account_balance_wallet),
            label: 'المحفظة',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.notifications),
            label: 'التنبيهات',
          ),
          BottomNavigationBarItem(icon: Icon(Icons.calculate), label: 'حاسبة'),
        ],
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        type: BottomNavigationBarType.fixed,
      ),
    );
  }
}

// --- Reusable Delete Confirmation Dialog ---
Future<void> showDeleteConfirmationDialog({
  required BuildContext context,
  required String title,
  required String content,
  required VoidCallback onConfirm,
}) async {
  return showDialog<void>(
    context: context,
    barrierDismissible: false, // User must tap button!
    builder: (BuildContext context) {
      return AlertDialog(
        title: Text(title),
        content: SingleChildScrollView(
          child: ListBody(children: <Widget>[Text(content)]),
        ),
        actions: <Widget>[
          TextButton(
            child: const Text('إلغاء'),
            onPressed: () {
              Navigator.of(context).pop();
            },
          ),
          TextButton(
            child: const Text('حذف'),
            onPressed: () {
              onConfirm();
              Navigator.of(context).pop();
            },
          ),
        ],
      );
    },
  );
}

// --- 1. Crypto List Screen ---

// --- 1. Crypto List Screen ---
class CryptoListScreen extends StatefulWidget {
  const CryptoListScreen({super.key});

  @override
  State<CryptoListScreen> createState() => _CryptoListScreenState();
}

class _CryptoListScreenState extends State<CryptoListScreen> {
  final Box _trackedCoinsBox = Hive.box('tracked_coins');
  Map<String, dynamic> _coinData = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchCoinData();
  }

  Future<void> _fetchCoinData() async {
    if (_trackedCoinsBox.isEmpty) {
      setState(() {
        _isLoading = false;
      });
      return;
    }

    final ids = _trackedCoinsBox.values.join(',');
    final url =
        'https://api.coingecko.com/api/v3/coins/markets?vs_currency=usd&ids=$ids';
    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        if (mounted) {
          setState(() {
            _coinData = {for (var item in data) item['id']: item};
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Failed to load data')));
      }
    }
  }

  void _showAddCoinDialog() {
    final TextEditingController controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('إضافة عملة جديدة'),
          content: TextField(
            controller: controller,
            decoration: const InputDecoration(hintText: 'مثال: bitcoin'),
          ),
          actions: [
            TextButton(
              onPressed: () {
                if (controller.text.isNotEmpty) {
                  _trackedCoinsBox.add(controller.text.toLowerCase());
                  _fetchCoinData();
                  Navigator.of(context).pop();
                }
              },
              child: const Text('إضافة'),
            ),
          ],
        );
      },
    );
  }

  void _navigateToDetail(String coinId, int index) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) =>
            CoinDetailScreen(coinId: coinId, indexInBox: index),
      ),
    );

    if (result == true && mounted) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('أسعار العملات'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: _showAddCoinDialog,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _fetchCoinData,
              child: ReorderableListView.builder(
                buildDefaultDragHandles:
                    false, // This hides the default drag handle
                itemCount: _trackedCoinsBox.length,
                // **** THIS IS THE CORRECTED onReorder FUNCTION ****
                onReorder: (int oldIndex, int newIndex) async {
                  // This logic handles the reordering of the item in the list.
                  if (newIndex > oldIndex) {
                    newIndex -= 1;
                  }

                  // 1. Read all items from Hive into a temporary Dart List.
                  final List items = _trackedCoinsBox.values.toList();

                  // 2. Reorder the items in the temporary List.
                  final String item = items.removeAt(oldIndex);
                  items.insert(newIndex, item);

                  // 3. Clear the Hive Box completely.
                  await _trackedCoinsBox.clear();

                  // 4. Write the newly ordered List back to the Hive Box.
                  await _trackedCoinsBox.addAll(items);

                  // Rebuild the UI with the new order.
                  setState(() {});
                },
                itemBuilder: (context, index) {
                  // We read from the box in its current (potentially new) order.
                  final coinId = _trackedCoinsBox.getAt(index);
                  final data = _coinData[coinId];

                  final key = ValueKey(coinId);

                  if (data == null) {
                    return ListTile(
                      key: key,
                      title: Text(coinId),
                      subtitle: const Text('Loading...'),
                    );
                  }

                  return ListTile(
                    key: key,
                    leading: Image.network(data['image'], height: 40),
                    title: Text(
                      '${data['name']} (${data['symbol'].toUpperCase()})',
                    ),
                    subtitle: Text('Price: \$${data['current_price']}'),
                    trailing: Padding(
                      padding: const EdgeInsets.only(right: 12.0),
                      child: Text(
                        '${data['price_change_percentage_24h'].toStringAsFixed(2)}%',
                        style: TextStyle(
                          color: data['price_change_percentage_24h'] >= 0
                              ? Colors.green
                              : Colors.red,
                        ),
                      ),
                    ),
                    onTap: () {
                      _navigateToDetail(coinId, index);
                    },
                  );
                },
              ),
            ),
    );
  }
}

// --- Coin Detail Screen (with Chart) ---
class CoinDetailScreen extends StatefulWidget {
  final String coinId;
  final int indexInBox;

  const CoinDetailScreen({
    super.key,
    required this.coinId,
    required this.indexInBox,
  });

  @override
  State<CoinDetailScreen> createState() => _CoinDetailScreenState();
}

class _CoinDetailScreenState extends State<CoinDetailScreen> {
  List<FlSpot> _chartData = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchChartData();
  }

  Future<void> _fetchChartData() async {
    final url =
        'https://api.coingecko.com/api/v3/coins/${widget.coinId}/market_chart?vs_currency=usd&days=7';
    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final List<dynamic> prices = data['prices'];
        if (mounted) {
          setState(() {
            _chartData = prices
                .map(
                  (price) => FlSpot(
                    (price[0] as int).toDouble(),
                    (price[1] as num).toDouble(),
                  ),
                )
                .toList();
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _deleteCoin() {
    showDeleteConfirmationDialog(
      context: context,
      title: 'حذف عملة',
      content:
          'هل أنت متأكد من رغبتك في حذف "${widget.coinId}" من قائمة المتابعة؟',
      onConfirm: () {
        final box = Hive.box('tracked_coins');
        box.deleteAt(widget.indexInBox);
        Navigator.of(context).pop(true);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.coinId.toUpperCase()),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline),
            onPressed: _deleteCoin,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.only(top: 80.0, left: 16, right: 16),
              child: SizedBox(
                height: 300,
                child: LineChart(
                  LineChartData(
                    lineBarsData: [
                      LineChartBarData(
                        spots: _chartData,
                        isCurved: true,
                        color: Colors.amber,
                        barWidth: 3,
                        dotData: const FlDotData(show: false),
                      ),
                    ],
                    titlesData: const FlTitlesData(
                      leftTitles: AxisTitles(
                        sideTitles: SideTitles(showTitles: false),
                      ),
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(showTitles: false),
                      ),
                      topTitles: AxisTitles(
                        sideTitles: SideTitles(showTitles: false),
                      ),
                      rightTitles: AxisTitles(
                        sideTitles: SideTitles(showTitles: false),
                      ),
                    ),
                    gridData: const FlGridData(show: false),
                    borderData: FlBorderData(show: false),
                  ),
                ),
              ),
            ),
    );
  }
}

// --- 2. Portfolio Screen ---
class PortfolioScreen extends StatefulWidget {
  const PortfolioScreen({super.key});

  @override
  State<PortfolioScreen> createState() => _PortfolioScreenState();
}

class _PortfolioScreenState extends State<PortfolioScreen> {
  final Box _portfolioBox = Hive.box('portfolio');
  Map<String, dynamic> _coinPrices = {};
  double _totalValue = 0.0;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchPortfolioData();
  }

  Future<void> _fetchPortfolioData() async {
    setState(() {
      _isLoading = true;
    });
    if (_portfolioBox.isEmpty) {
      setState(() {
        _totalValue = 0.0;
        _isLoading = false;
      });
      return;
    }

    final ids = _portfolioBox.keys.cast<String>().join(',');
    final url =
        'https://api.coingecko.com/api/v3/simple/price?ids=$ids&vs_currencies=usd';
    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        double total = 0.0;
        data.forEach((key, value) {
          final amount = _portfolioBox.get(key) as double;
          total += (value['usd'] as num) * amount;
        });
        if (mounted) {
          setState(() {
            _coinPrices = data;
            _totalValue = total;
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _showAddPortfolioItemDialog() {
    final TextEditingController idController = TextEditingController();
    final TextEditingController amountController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('إضافة عملة للمحفظة'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: idController,
                decoration: const InputDecoration(
                  hintText: 'Coin ID (e.g., bitcoin)',
                ),
              ),
              TextField(
                controller: amountController,
                decoration: const InputDecoration(hintText: 'الكمية'),
                keyboardType: TextInputType.number,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                final id = idController.text.toLowerCase();
                final amount = double.tryParse(amountController.text);
                if (id.isNotEmpty && amount != null) {
                  _portfolioBox.put(id, amount);
                  _fetchPortfolioData();
                  Navigator.of(context).pop();
                }
              },
              child: const Text('إضافة'),
            ),
          ],
        );
      },
    );
  }

  void _deletePortfolioItem(String coinId) {
    showDeleteConfirmationDialog(
      context: context,
      title: 'حذف من المحفظة',
      content: 'هل أنت متأكد من رغبتك في حذف "$coinId" من محفظتك؟',
      onConfirm: () {
        _portfolioBox.delete(coinId);
        _fetchPortfolioData();
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('المحفظة'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add, color: Colors.white),

            onPressed: _showAddPortfolioItemDialog,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Container(
                    padding: EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.grey[700],
                      borderRadius: BorderRadius.circular(8.0),
                    ),
                    child: Text(
                      'إجمالي القيمة: \$${_totalValue.toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                SizedBox(height: 25),
                Expanded(
                  child: ListView.builder(
                    itemCount: _portfolioBox.length,
                    itemBuilder: (context, index) {
                      final coinId = _portfolioBox.keyAt(index) as String;
                      final amount = _portfolioBox.get(coinId) as double;
                      final priceData = _coinPrices[coinId];
                      final price = priceData != null
                          ? priceData['usd'] as num
                          : 0;
                      final value = price * amount;

                      return ListTile(
                        title: Text(coinId.toUpperCase()),
                        subtitle: Text('الكمية: $amount'),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              '\$${value.toStringAsFixed(0)}',
                              style: TextStyle(fontSize: 22),
                            ),
                            IconButton(
                              icon: const Icon(
                                Icons.delete_outline,
                                color: Colors.grey,
                              ),
                              onPressed: () => _deletePortfolioItem(coinId),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
    );
  }
}

// --- 3. Alerts Screen ---
class AlertsScreen extends StatefulWidget {
  const AlertsScreen({super.key});

  @override
  State<AlertsScreen> createState() => _AlertsScreenState();
}

class _AlertsScreenState extends State<AlertsScreen> {
  final Box _alertsBox = Hive.box('alerts');

  void _showAddAlertDialog() {
    final TextEditingController idController = TextEditingController();
    final TextEditingController priceController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('إضافة تنبيه جديد'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: idController,
                decoration: const InputDecoration(
                  hintText: 'Coin ID (e.g., bitcoin)',
                ),
              ),
              TextField(
                controller: priceController,
                decoration: const InputDecoration(hintText: 'السعر المستهدف'),
                keyboardType: TextInputType.number,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                final id = idController.text.toLowerCase();
                final price = double.tryParse(priceController.text);
                if (id.isNotEmpty && price != null) {
                  setState(() {
                    _alertsBox.put(id, price);
                  });
                  Navigator.of(context).pop();
                }
              },
              child: const Text('إضافة'),
            ),
          ],
        );
      },
    );
  }

  void _deleteAlert(String coinId) {
    showDeleteConfirmationDialog(
      context: context,
      title: 'حذف تنبيه',
      content: 'هل أنت متأكد من رغبتك في حذف التنبيه الخاص بـ "$coinId"؟',
      onConfirm: () {
        setState(() {
          _alertsBox.delete(coinId);
        });
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('التنبيهات'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add, color: Colors.white),

            onPressed: _showAddAlertDialog,
          ),
        ],
      ),
      body: ListView.builder(
        itemCount: _alertsBox.length,
        itemBuilder: (context, index) {
          final coinId = _alertsBox.keyAt(index) as String;
          final price = _alertsBox.get(coinId) as double;

          return ListTile(
            title: Text('تنبيه لـ ${coinId.toUpperCase()}'),
            subtitle: Text('عند وصول السعر إلى: \$$price'),
            trailing: IconButton(
              icon: const Icon(Icons.delete_outline, color: Colors.grey),
              onPressed: () => _deleteAlert(coinId),
            ),
          );
        },
      ),
    );
  }
}

// --- 4. Calculator Screen ---
class CalculatorScreen extends StatefulWidget {
  const CalculatorScreen({super.key});

  @override
  State<CalculatorScreen> createState() => _CalculatorScreenState();
}

class _CalculatorScreenState extends State<CalculatorScreen> {
  final TextEditingController _controller = TextEditingController();

  // نستخدم MapEntry لتخزين النسبة (int) كـ Key والسعر (double) كـ Value
  final List<MapEntry<int, double>> _increases = [];
  final List<MapEntry<int, double>> _decreases = [];

  void _calculate() {
    final double? value = double.tryParse(_controller.text);
    _increases.clear();
    _decreases.clear();

    if (value != null) {
      // 1. تعريف الخطوات المطلوبة: من 1 إلى 10، ثم عشرات حتى 100
      List<int> steps = [
        1,
        2,
        3,
        4,
        5,
        6,
        7,
        8,
        9,
        10,
        20,
        30,
        40,
        50,
        60,
        70,
        80,
        90,
        100,
      ];

      // 2. المرور على كل خطوة وحساب السعر
      for (int percent in steps) {
        _increases.add(MapEntry(percent, value * (1 + percent / 100.0)));
        _decreases.add(MapEntry(percent, value * (1 - percent / 100.0)));
      }
    }
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final headerStyle = Theme.of(
      context,
    ).textTheme.titleLarge?.copyWith(color: Colors.white);
    final greenStyle = const TextStyle(color: Colors.green, fontSize: 16);
    final redStyle = const TextStyle(color: Colors.red, fontSize: 16);
    final percentStyle = TextStyle(color: Colors.grey[400], fontSize: 16);

    return Scaffold(
      appBar: AppBar(title: const Text('حاسبة الأهداف')),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: _controller,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(
                  labelText: 'أدخل السعر الحالي',
                  border: OutlineInputBorder(),
                ),
                onChanged: (text) => _calculate(),
              ),
              const SizedBox(height: 24),
              if (_increases.isNotEmpty)
                IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // --- Profit Targets Column ---
                      Expanded(
                        child: Column(
                          children: [
                            Text("أهداف البيع (زيادة)", style: headerStyle),
                            const SizedBox(height: 8),
                            // نستخدم البيانات المخزنة مباشرة
                            ..._increases.map((entry) {
                              int percent =
                                  entry.key; // النسبة المخزنة (مثلاً 20)
                              double price = entry.value; // السعر المحسوب
                              return Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 4.0,
                                ),
                                child: Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text("+$percent%", style: percentStyle),
                                    Text(
                                      '\$${price.toStringAsFixed(4)}',
                                      style: greenStyle,
                                    ),
                                  ],
                                ),
                              );
                            }).toList(),
                          ],
                        ),
                      ),

                      const VerticalDivider(
                        width: 20,
                        thickness: 1,
                        indent: 40,
                        endIndent: 10,
                        color: Colors.grey,
                      ),

                      // --- Loss Targets Column ---
                      Expanded(
                        child: Column(
                          children: [
                            Text("أهداف الشراء (نقصان)", style: headerStyle),
                            const SizedBox(height: 8),
                            ..._decreases.map((entry) {
                              int percent = entry.key;
                              double price = entry.value;
                              return Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 4.0,
                                ),
                                child: Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text("-$percent%", style: percentStyle),
                                    Text(
                                      '\$${price.toStringAsFixed(4)}',
                                      style: redStyle,
                                    ),
                                  ],
                                ),
                              );
                            }).toList(),
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
    );
  }
}
