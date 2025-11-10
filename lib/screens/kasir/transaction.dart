// file: lib/screens/kasir_screen.dart

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../services/cashier_service.dart'; // Impor ApiService dan Models

class KasirScreen extends StatefulWidget {
  const KasirScreen({super.key});

  @override
  State<KasirScreen> createState() => _KasirScreenState();
}

class _KasirScreenState extends State<KasirScreen> {
  // State
  bool _isLoggedIn = false;
  String _username = '';
  String _password = '';
  String _customerName = '';
  String? _voucherCode;
  int _amountReceived = 0;
  List<Product> _products = [];
  List<CartItem> _cart = [];
  List<Voucher> _vouchers = [];
  String _search = '';
  String _selectedCategory = 'All';
  double _discount = 0;
  final ApiService _apiService = ApiService();

  @override
  void initState() {
    super.initState();
    _checkLoginStatus();
  }

  Future<void> _checkLoginStatus() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    setState(() {
      _isLoggedIn = token != null;
    });
    if (_isLoggedIn) {
      _loadData();
    }
  }

  Future<void> _loadData() async {
    try {
      final loadedProducts = await _apiService.loadProducts();
      final loadedVouchers = await _apiService.loadVouchers();
      setState(() {
        _products = loadedProducts;
        _vouchers = loadedVouchers;
        _selectedCategory = 'All'; // Reset filter
      });
    } catch (e) {
      if (e.toString().contains('Unauthorized')) {
        setState(() => _isLoggedIn = false);
      }
      // Tampilkan error
      _showSnackbar(context, e.toString(), isError: true);
    }
  }

  Future<void> _login() async {
    if (_username.isEmpty || _password.isEmpty) {
      _showSnackbar(context, 'Username dan Password wajib diisi.',
          isError: true);
      return;
    }
    try {
      await _apiService.login(_username, _password);
      setState(() {
        _isLoggedIn = true;
      });
      _loadData();
    } catch (e) {
      _showSnackbar(context, e.toString(), isError: true);
    }
  }

  // --- Logic Produk dan Keranjang ---

  List<Product> get _filteredProducts {
    final uniqueCategories = {'All'};
    uniqueCategories.addAll(_products.map((p) => p.categoryName));

    final products = _products.where((p) {
      final matchSearch =
          p.name.toLowerCase().contains(_search.toLowerCase());
      final matchCategory = _selectedCategory == 'All' ||
          p.categoryName == _selectedCategory;
      return matchSearch && matchCategory;
    }).toList();

    // Pastikan kategori yang dipilih ada
    if (!uniqueCategories.contains(_selectedCategory)) {
      _selectedCategory = 'All';
    }

    return products;
  }

  void _addToCart(Product product) {
    if (product.stock == 0) {
      _showSnackbar(context, 'Stok produk ${product.name} habis!',
          isError: true);
      return;
    }

    setState(() {
      final existing = _cart.firstWhere(
        (i) => i.id == product.id,
        orElse: () => CartItem(
            id: -1, name: '', sellPrice: 0, stock: 0), // Default item fiktif
      );

      if (existing.id != -1) {
        if (existing.qty < product.stock) {
          existing.qty++;
        } else {
          _showSnackbar(context,
              'Stok ${product.name} hanya tersedia ${product.stock} unit!',
              isError: true);
        }
      } else {
        _cart.add(CartItem.fromProduct(product));
      }
    });
  }

  void _removeFromCart(int index) {
    setState(() {
      _cart.removeAt(index);
    });
    _validateVoucher(); // Recalculate discount
  }

  void _validateQuantity(CartItem item) {
    if (item.qty > item.stock) {
      item.qty = item.stock;
      _showSnackbar(context,
          'Stok ${item.name} hanya tersedia ${item.stock} unit!',
          isError: true);
    } else if (item.qty < 1) {
      item.qty = 1;
      _showSnackbar(context, 'Jumlah minimal 1!', isError: true);
    }
    setState(() {}); // Trigger UI update
    _validateVoucher(); // Recalculate discount
  }

  // --- Logic Pembayaran ---

  int get _subtotal => _cart.fold(
      0, (sum, item) => sum + (item.sellPrice * item.qty));

  int get _totalAmount =>
      (_subtotal - _discount.toInt()).clamp(0, double.infinity).toInt();

  int get _change => (_amountReceived - _totalAmount).clamp(0, double.infinity).toInt();

  void _validateVoucher() {
    double tempDiscount = 0;
    if (_voucherCode == null || _voucherCode!.isEmpty) {
      tempDiscount = 0;
    } else {
      final selectedVoucher = _vouchers.firstWhere(
        (v) => v.code == _voucherCode,
        orElse: () => Voucher(
            id: -1, code: '', type: '', value: 0, active: false),
      );

      if (selectedVoucher.id != -1) {
        switch (selectedVoucher.type) {
          case 'PERCENT':
            tempDiscount = (selectedVoucher.value / 100) * _subtotal;
            break;
          case 'AMOUNT':
            tempDiscount =
                selectedVoucher.value.clamp(0, _subtotal.toDouble());
            break;
          default:
            tempDiscount = 0;
        }
      } else {
        _showSnackbar(context, 'Voucher tidak ditemukan!', isError: true);
        _voucherCode = null;
      }
    }
    setState(() {
      _discount = tempDiscount;
    });
  }

  Future<void> _checkout() async {
    if (_cart.isEmpty) {
      _showSnackbar(context, 'Cart masih kosong!', isError: true);
      return;
    }
    if (_amountReceived < _totalAmount) {
      _showSnackbar(context, 'Uang kurang!', isError: true);
      return;
    }

    try {
      final transactionId = await _apiService.checkout(
        _customerName.isEmpty ? null : _customerName,
        _voucherCode,
        _amountReceived,
        _cart,
      );

      // Pemberitahuan dan Reset State
      _showSnackbar(context, 'Pembayaran berhasil! ID Transaksi: $transactionId');
      setState(() {
        _cart = [];
        _amountReceived = 0;
        _customerName = '';
        _voucherCode = null;
        _discount = 0;
      });
      _loadData(); // Refresh produk/stok
    } catch (e) {
      _showSnackbar(context, e.toString(), isError: true);
    }
  }

  void _showSnackbar(BuildContext context, String message,
      {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : Colors.green,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Kasir - Order'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),
      body: _isLoggedIn ? _buildCashierLayout() : _buildLoginScreen(),
    );
  }

  // --- Widget Login ---

  Widget _buildLoginScreen() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Card(
          elevation: 4,
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Login Kasir',
                    style:
                        TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),
                TextField(
                  onChanged: (value) => _username = value,
                  decoration: const InputDecoration(
                    labelText: 'Username',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  onChanged: (value) => _password = value,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'Password',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: _login,
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 40),
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Login'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // --- Widget Cashier Main Layout ---

  Widget _buildCashierLayout() {
    return Row(
      children: [
        // Product List (Expanded to take more space on wide screens like tablet/desktop)
        Expanded(
          flex: 2,
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Available Products',
                    style:
                        TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        onChanged: (value) {
                          setState(() => _search = value);
                        },
                        decoration: const InputDecoration(
                          hintText: 'Cari produk...',
                          border: OutlineInputBorder(),
                          contentPadding: EdgeInsets.symmetric(horizontal: 10),
                          isDense: true,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    DropdownButton<String>(
                      value: _selectedCategory,
                      items: {'All'}
                          .union(_products.map((p) => p.categoryName).toSet())
                          .map((String category) {
                        return DropdownMenuItem<String>(
                          value: category,
                          child: Text(category == 'All' ? 'Semua Kategori' : category),
                        );
                      }).toList(),
                      onChanged: (String? newValue) {
                        if (newValue != null) {
                          setState(() => _selectedCategory = newValue);
                        }
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Expanded(
                  child: GridView.builder(
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2, // 2 columns for mobile/tablet
                      crossAxisSpacing: 10,
                      mainAxisSpacing: 10,
                      childAspectRatio: 1.5,
                    ),
                    itemCount: _filteredProducts.length,
                    itemBuilder: (context, index) {
                      final p = _filteredProducts[index];
                      return _buildProductCard(p);
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
        // Cart Order and Summary (Fixed width for mobile/tablet feel, but flexible)
        Expanded(
          flex: 1,
          child: Container(
            padding: const EdgeInsets.all(16.0),
            color: Colors.grey[50],
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Cart Order',
                    style:
                        TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 10),
                _buildCartList(),
                const SizedBox(height: 16),
                _buildOrderSummary(),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // --- Widget Detail ---

  Widget _buildProductCard(Product p) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(p.name,
                    style: const TextStyle(fontWeight: FontWeight.bold)),
                Text(formatCurrency(p.sellPrice),
                    style: const TextStyle(fontSize: 12, color: Colors.grey)),
                Text('Stock: ${p.stock}',
                    style: const TextStyle(fontSize: 10, color: Colors.green)),
              ],
            ),
            ElevatedButton(
              onPressed: p.stock > 0 ? () => _addToCart(p) : null,
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 30),
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
              ),
              child: const Text('Add', style: TextStyle(fontSize: 12)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCartList() {
    return Expanded(
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade300),
          borderRadius: BorderRadius.circular(8.0),
          color: Colors.white,
        ),
        child: SingleChildScrollView(
          child: Table(
            columnWidths: const {
              0: FlexColumnWidth(3),
              1: FlexColumnWidth(2),
              2: FlexColumnWidth(2),
              3: FlexColumnWidth(1),
            },
            children: [
              const TableRow(
                decoration: BoxDecoration(color: Colors.grey),
                children: [
                  Padding(
                    padding: EdgeInsets.all(8.0),
                    child: Text('Item',
                        style: TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 12)),
                  ),
                  Padding(
                    padding: EdgeInsets.all(8.0),
                    child: Text('Qty',
                        style: TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 12)),
                  ),
                  Padding(
                    padding: EdgeInsets.all(8.0),
                    child: Text('Subtotal',
                        style: TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 12)),
                  ),
                  Padding(
                    padding: EdgeInsets.all(8.0),
                    child: Text('X',
                        style: TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 12)),
                  ),
                ],
              ),
              if (_cart.isEmpty)
                const TableRow(
                  children: [
                    Padding(
                      padding: EdgeInsets.all(8.0),
                      child: Text('Cart kosong',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontStyle: FontStyle.italic)),
                    ),
                    SizedBox(),
                    SizedBox(),
                    SizedBox(),
                  ],
                ),
              ..._cart.asMap().entries.map((entry) {
                final index = entry.key;
                final item = entry.value;
                return TableRow(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Text(item.name, style: const TextStyle(fontSize: 12)),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(4.0),
                      child: IntrinsicWidth(
                        child: TextField(
                          keyboardType: TextInputType.number,
                          controller: TextEditingController(
                              text: item.qty.toString()),
                          onChanged: (value) {
                            int? newQty = int.tryParse(value);
                            if (newQty != null) {
                              item.qty = newQty;
                              _validateQuantity(item);
                            }
                          },
                          decoration: InputDecoration(
                            border: const OutlineInputBorder(),
                            isDense: true,
                            contentPadding:
                                const EdgeInsets.symmetric(horizontal: 5),
                            constraints: BoxConstraints.loose(
                                const Size.fromWidth(50)),
                          ),
                          style: const TextStyle(fontSize: 12),
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Text(
                          formatCurrency(item.sellPrice * item.qty),
                          style: const TextStyle(fontSize: 12)),
                    ),
                    Center(
                      child: IconButton(
                        icon: const Icon(Icons.close,
                            color: Colors.red, size: 16),
                        onPressed: () => _removeFromCart(index),
                      ),
                    ),
                  ],
                );
              }).toList(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOrderSummary() {
    return Container(
      padding: const EdgeInsets.all(12.0),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(8.0),
        color: Colors.white,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Order Summary',
              style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          _buildSummaryRow('Subtotal', _subtotal),
          _buildSummaryRow('Discount', _discount.toInt()),
          const Divider(),
          _buildSummaryRow('Total', _totalAmount, isTotal: true),
          const SizedBox(height: 12),
          // Customer Name
          const Text('Customer Name (Optional)',
              style: TextStyle(fontSize: 12)),
          TextField(
            onChanged: (value) => _customerName = value,
            decoration: const InputDecoration(
                hintText: 'Nama pelanggan', border: OutlineInputBorder(), isDense: true),
            style: const TextStyle(fontSize: 14),
          ),
          const SizedBox(height: 8),
          // Voucher
          const Text('Voucher (Optional)', style: TextStyle(fontSize: 12)),
          DropdownButtonFormField<String>(
            decoration: const InputDecoration(
                border: OutlineInputBorder(), isDense: true, contentPadding: EdgeInsets.symmetric(horizontal: 10)),
            value: _voucherCode,
            hint: const Text('Pilih Voucher', style: TextStyle(fontSize: 14)),
            items: _vouchers.map((v) {
              return DropdownMenuItem<String>(
                value: v.code,
                child: Text('${v.code} (${v.type}: ${v.value})', style: const TextStyle(fontSize: 14)),
              );
            }).toList(),
            onChanged: (String? newValue) {
              setState(() {
                _voucherCode = newValue;
                _validateVoucher();
              });
            },
          ),
          const SizedBox(height: 8),
          // Amount Received
          const Text('Amount Received', style: TextStyle(fontSize: 12)),
          TextField(
            keyboardType: TextInputType.number,
            onChanged: (value) {
              setState(() {
                _amountReceived = int.tryParse(value) ?? 0;
              });
            },
            decoration: const InputDecoration(
                hintText: 'Masukkan nominal', border: OutlineInputBorder(), isDense: true),
            style: const TextStyle(fontSize: 14),
          ),
          const SizedBox(height: 4),
          Text('Change: ${formatCurrency(_change)}',
              style: const TextStyle(fontSize: 14)),
          const SizedBox(height: 16),
          // Pay Now Button
          ElevatedButton(
            onPressed: _checkout,
            style: ElevatedButton.styleFrom(
              minimumSize: const Size(double.infinity, 40),
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
            ),
            child: const Text('Pay Now'),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryRow(String label, int amount,
      {bool isTotal = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: TextStyle(
                  fontSize: 14,
                  fontWeight: isTotal ? FontWeight.bold : FontWeight.normal)),
          Text(formatCurrency(amount),
              style: TextStyle(
                  fontSize: 14,
                  fontWeight: isTotal ? FontWeight.bold : FontWeight.normal)),
        ],
      ),
    );
  }
}