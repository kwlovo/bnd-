import 'package:flutter/material.dart';

import 'screens/groups_page.dart';
import 'screens/inventory.dart';
import 'screens/ledger_page.dart';
import 'screens/stats_page.dart';
import 'store.dart';
import 'ui.dart';

final store = Store();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await store.load();
  runApp(const MerchApp());
}

class MerchApp extends StatelessWidget {
  const MerchApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: '追星周邊管理',
        debugShowCheckedModeBanner: false,
        theme: appTheme(),
        home: const Home(),
      );
}

class Home extends StatefulWidget {
  const Home({super.key});
  @override
  State<Home> createState() => _HomeState();
}

class _HomeState extends State<Home> {
  int tab = 0;

  @override
  Widget build(BuildContext context) => Scaffold(
        body: SafeArea(
          child: IndexedStack(index: tab, children: const [
            InventoryPage(),
            GroupsPage(),
            LedgerPage(),
            StatsPage(),
          ]),
        ),
        bottomNavigationBar: NavigationBar(
          selectedIndex: tab,
          onDestinationSelected: (i) => setState(() => tab = i),
          backgroundColor: Colors.white,
          destinations: const [
            NavigationDestination(icon: Icon(Icons.inventory_2_outlined), label: '庫存'),
            NavigationDestination(icon: Icon(Icons.groups_outlined), label: '拼團'),
            NavigationDestination(icon: Icon(Icons.receipt_long_outlined), label: '記帳'),
            NavigationDestination(icon: Icon(Icons.bar_chart), label: '統計'),
          ],
        ),
      );
}
