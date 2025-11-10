import 'package:flutter/material.dart';
// Import Halaman yang sudah ada
import 'screens/login_screens.dart';
import 'screens/kasir/dashboard_cashier.dart';

// 🆕 Tambahan: Import Halaman Baru (Retur dan Dashboard Admin/Manajer)
import 'screens/kasir/return.dart'; // Asumsi: Halaman Retur
import 'screens/kasir/transaction.dart'; // Asumsi: Dashboard untuk Admin/Manager

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      // 🚀 Pengaturan Utama Aplikasi
      debugShowCheckedModeBanner: false,
      title: 'Penjualan App',
      theme: ThemeData(
        primarySwatch: Colors.indigo,
        useMaterial3: true,
      ),

      // 🗺️ Penentuan Rute (Halaman) Aplikasi
      initialRoute: '/',
      routes: {
        // Rute yang sudah ada
        '/': (context) => const LoginScreen(),
        '/dashboard-cashier': (context) => const DashboardCashier(),

        // 🆕 Tambahan: Rute Baru
        '/retur': (context) => const ReturScreen(), // Rute untuk Halaman Retur
         '/transactions': (context) => const KasirScreen(),
      },
    );
  }
}