// lib/widgets/bottom_nav_widget.dart

import 'package:flutter/material.dart';

class BottomNavWidget extends StatelessWidget {
  // 1. currentIndex: Indeks dari tab yang sedang aktif.
  final int currentIndex;
  // 2. onTap: Fungsi yang akan dipanggil saat pengguna menekan item nav.
  final Function(int) onTap; 

  const BottomNavWidget({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return BottomNavigationBar(
      // Tentukan indeks yang aktif
      currentIndex: currentIndex,
      // Panggil fungsi onTap yang disediakan dari luar
      onTap: onTap,
      items: const [
        BottomNavigationBarItem(
          icon: Icon(Icons.home),
          label: 'Home',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.category),
          label: 'Transactions',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.person),
          label: 'Return',
        ),
      ],
    );
  }
}