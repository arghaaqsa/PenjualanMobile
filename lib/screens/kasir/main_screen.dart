// lib/screens/main_screen.dart

import 'package:flutter/material.dart';
import '../../widgets/bottom_nav_widgets.dart'; // Import widget yang sudah dibuat

// Anda perlu mendefinisikan screens Anda di sini
import 'dashboard_cashier.dart'; 
import 'transaction.dart';
import 'return.dart';


class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0; // State untuk menyimpan indeks tab aktif

  // List semua halaman/screen yang akan ditampilkan
  final List<Widget> _screens = [
    const DashboardCashier(), 
    const KasirScreen(),
    const ReturScreen(),
  ];

  void _onTabTapped(int index) {
    setState(() {
      _currentIndex = index; // Ubah state saat tab ditekan
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Tampilkan screen berdasarkan _currentIndex
      body: _screens[_currentIndex], 
      
      // Panggil widget Bottom Navigation Bar yang sudah dibuat
      bottomNavigationBar: BottomNavWidget(
        currentIndex: _currentIndex, // Berikan state saat ini
        onTap: _onTabTapped,        // Berikan fungsi untuk mengubah state
      ),
    );
  }
}