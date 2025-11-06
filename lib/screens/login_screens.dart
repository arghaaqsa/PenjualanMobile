import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api_service.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  String? _errorMessage;
  bool _isLoading = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _errorMessage = null;
      _isLoading = true;
    });

    try {
      final response = await ApiService.post('/auth/login', {
        'email': _emailController.text.trim(),
        'password': _passwordController.text,
      });

      if (response.statusCode == 200) {
        final data = response.data['data'] as Map<String, dynamic>;
        final token = data['token'] as String;
        final role = data['role'] as String;

        // Simpan token dan role
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('token', token);
        await prefs.setString('userRole', role);

        // Redirect berdasarkan role (sesuaikan route kamu)
        if (mounted) {
          _navigateToDashboard(role);
        }
      }
    } on DioException catch (e) {
      if (e.response?.statusCode == 401) {
        setState(() => _errorMessage = 'Email atau password salah!');
      } else {
        setState(() => _errorMessage = 'Terjadi kesalahan saat login. Mohon coba lagi.');
      }
      debugPrint('Error login: ${e.message}');
    } catch (e) {
      setState(() => _errorMessage = 'Terjadi kesalahan tak terduga.');
      debugPrint('Unexpected error: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _navigateToDashboard(String role) {
    // Ganti dengan Navigator.pushReplacementNamed atau router kamu
    switch (role) {
      case 'OWNER':
        Navigator.pushReplacementNamed(context, '/dashboard-owner');
        break;
      case 'KASIR':
        Navigator.pushReplacementNamed(context, '/dashboard-cashier');
        break;
      case 'GUDANG':
        Navigator.pushReplacementNamed(context, '/dashboard-gudang');
        break;
      case 'PEMBELIAN':
        Navigator.pushReplacementNamed(context, '/dashboard-pembelian');
        break;
      case 'KEPALA_GUDANG':
        Navigator.pushReplacementNamed(context, '/dashboard-kepalagudang');
        break;
      default:
        Navigator.pushReplacementNamed(context, '/');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        // PERUBAHAN: Background full putih polos (mirip web bg-gray-50)
        decoration: const BoxDecoration(
          color: Colors.white,  // Putih polos, atau Color(0xFFF9FAFB) kalau mau grey light
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // PERUBAHAN: Form di tengah, dibungkus Stack buat gambar di bawah kanan
                  Stack(
                    alignment: Alignment.bottomRight,
                    children: [
                      Card(
                        elevation: 20,
                        shadowColor: Colors.black.withValues(alpha: 0.08),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(24),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(24.0),
                          child: Form(
                            key: _formKey,
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const SizedBox(height: 20),
                                Text(
                                  'Welcome Back',
                                  style: GoogleFonts.poppins(
                                    fontSize: 28,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.black87,  // Hitam seperti web
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Hello, friend! task manager you can trust everything. Let\'s get in touch!',
                                  style: GoogleFonts.poppins(
                                    fontSize: 14,
                                    color: Colors.grey[600],  // Grey seperti web
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: 30),
                                TextFormField(
                                  controller: _emailController,
                                  keyboardType: TextInputType.emailAddress,
                                  decoration: InputDecoration(
                                    hintText: 'Email',
                                    hintStyle: TextStyle(color: Colors.grey[500]),
                                    prefixIcon: Icon(Icons.email_outlined, color: Colors.grey[500]),
                                    filled: true,
                                    fillColor: Colors.grey[50],  // Grey light seperti web
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(16),
                                      borderSide: BorderSide(color: Colors.grey[200]!),
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(16),
                                      borderSide: const BorderSide(color: Color(0xFF4F46E5)),
                                    ),
                                    enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(16),
                                      borderSide: BorderSide(color: Colors.grey[200]!),
                                    ),
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                  ),
                                  validator: (value) {
                                    if (value == null || value.isEmpty) return 'Email wajib diisi';
                                    if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value)) {
                                      return 'Format email tidak valid';
                                    }
                                    return null;
                                  },
                                  style: GoogleFonts.poppins(),
                                ),
                                const SizedBox(height: 16),
                                TextFormField(
                                  controller: _passwordController,
                                  obscureText: true,
                                  decoration: InputDecoration(
                                    hintText: 'Password',
                                    hintStyle: TextStyle(color: Colors.grey[500]),
                                    prefixIcon: Icon(Icons.lock_outlined, color: Colors.grey[500]),
                                    filled: true,
                                    fillColor: Colors.grey[50],
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(16),
                                      borderSide: BorderSide(color: Colors.grey[200]!),
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(16),
                                      borderSide: const BorderSide(color: Color(0xFF4F46E5)),
                                    ),
                                    enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(16),
                                      borderSide: BorderSide(color: Colors.grey[200]!),
                                    ),
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                  ),
                                  validator: (value) {
                                    if (value == null || value.isEmpty) return 'Password wajib diisi';
                                    if (value.length < 6) return 'Password minimal 6 karakter';
                                    return null;
                                  },
                                  style: GoogleFonts.poppins(),
                                ),
                                if (_errorMessage != null) ...[
                                  const SizedBox(height: 16),
                                  Container(
                                    width: double.infinity,
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: Colors.red[50],
                                      borderRadius: BorderRadius.circular(16),
                                      border: Border.all(color: Colors.red[300]!),
                                    ),
                                    child: Text(
                                      _errorMessage!,
                                      style: GoogleFonts.poppins(color: Colors.red[700], fontSize: 14),
                                    ),
                                  ),
                                ],
                                const SizedBox(height: 24),
                                SizedBox(
                                  width: double.infinity,
                                  height: 56,
                                  child: ElevatedButton(
                                    onPressed: _isLoading ? null : _handleLogin,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFF4F46E5),  // Indigo seperti web
                                      foregroundColor: Colors.white,
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                      elevation: 8,
                                      shadowColor: const Color(0xFF4F46E5).withValues(alpha: 0.3),
                                    ),
                                    child: _isLoading
                                        ? const SizedBox(
                                            height: 24,
                                            width: 24,
                                            child: CircularProgressIndicator(
                                              color: Colors.white,
                                              strokeWidth: 2,
                                            ),
                                          )
                                        : Text(
                                            'Let\'s start!',
                                            style: GoogleFonts.poppins(
                                              fontSize: 16,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                  ),
                                ),
                                const SizedBox(height: 40),  // Space buat gambar di bawah
                              ],
                            ),
                          ),
                        ),
                      ),
                      // PERUBAHAN: Gambar polos di bawah kanan form (ukuran kecil)
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          child: Image.asset(
                            'images/loginweb.png',
                            width: 120,
                            height: 120,
                            fit: BoxFit.contain,
                            errorBuilder: (context, error, stackTrace) => const Icon(Icons.person, size: 80, color: Colors.grey),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}