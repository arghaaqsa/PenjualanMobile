import 'package:flutter/material.dart';
import 'screens/login_screens.dart';
import 'screens/dashboard_cashier.dart'; // cuma import yang dipakai

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Penjualan App',
      theme: ThemeData(
        primarySwatch: Colors.indigo,
      ),
      initialRoute: '/',
      routes: {
        '/': (context) => const LoginScreen(),
        '/dashboard-cashier': (context) => const DashboardCashier(),
      },
    );
  }
}
