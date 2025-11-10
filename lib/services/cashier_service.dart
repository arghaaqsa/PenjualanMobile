// file: lib/services/api_service.dart

import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

// --- Data Models Sederhana ---

class Product {
  final int id;
  final String name;
  final int sellPrice;
  final int stock;
  final String categoryName;

  Product({
    required this.id,
    required this.name,
    required this.sellPrice,
    required this.stock,
    required this.categoryName,
  });

  factory Product.fromJson(Map<String, dynamic> json) {
    // Sesuaikan parsing dengan struktur API Anda
    final category = json['category'];
    return Product(
      id: json['id'],
      name: json['name'] ?? 'N/A',
      sellPrice: (json['sell_price'] as num?)?.toInt() ?? 0,
      stock: (json['stock'] as num?)?.toInt() ?? 0,
      categoryName: category != null ? (category['name'] ?? 'Unknown') : 'Unknown',
    );
  }
}

class CartItem {
  final int id;
  final String name;
  final int sellPrice;
  final int stock;
  int qty;

  CartItem({
    required this.id,
    required this.name,
    required this.sellPrice,
    required this.stock,
    this.qty = 1,
  });

  factory CartItem.fromProduct(Product product) {
    return CartItem(
      id: product.id,
      name: product.name,
      sellPrice: product.sellPrice,
      stock: product.stock,
      qty: 1,
    );
  }
}

class Voucher {
  final int id;
  final String code;
  final String type;
  final double value;
  final bool active;

  Voucher({
    required this.id,
    required this.code,
    required this.type,
    required this.value,
    required this.active,
  });

  factory Voucher.fromJson(Map<String, dynamic> json) {
    return Voucher(
      id: json['ID'] ?? 0,
      code: json['Code'] ?? '',
      type: json['Type'] ?? 'AMOUNT',
      value: (json['Value'] as num?)?.toDouble() ?? 0.0,
      active: json['Active'] ?? false,
    );
  }
}

class SaleHistory {
  final int id;
  final DateTime date;
  final String transactionNumber;
  final int total;
  final List<SaleItem> items; // Untuk detail di Retur

  SaleHistory({
    required this.id,
    required this.date,
    required this.transactionNumber,
    required this.total,
    required this.items,
  });

  factory SaleHistory.fromJson(Map<String, dynamic> json) {
    return SaleHistory(
      id: json['ID'] ?? 0,
      date: DateTime.tryParse(json['Date'] ?? '') ?? DateTime.now(),
      transactionNumber: json['transaction_number'] ?? 'N/A',
      total: (json['Total'] as num?)?.toInt() ?? 0,
      items: (json['Items'] as List<dynamic>?)
              ?.map((i) => SaleItem.fromJson(i))
              .toList() ??
          [],
    );
  }
}

class SaleItem {
  final int productID;
  final int qty;
  final int price;
  final String productName;

  SaleItem({
    required this.productID,
    required this.qty,
    required this.price,
    required this.productName,
  });

  factory SaleItem.fromJson(Map<String, dynamic> json) {
    return SaleItem(
      productID: json['ProductID'] ?? 0,
      qty: (json['Qty'] as num?)?.toInt() ?? 0,
      price: (json['Price'] as num?)?.toInt() ?? 0,
      productName: json['Product'] != null ? json['Product']['name'] ?? 'Unknown Product' : 'Unknown Product',
    );
  }
}

class SaleReturn {
  final int id;
  final int saleId;
  final DateTime date;
  final int total;
  final String status;
  final String transactionNumber;

  SaleReturn({
    required this.id,
    required this.saleId,
    required this.date,
    required this.total,
    required this.status,
    required this.transactionNumber,
  });

  factory SaleReturn.fromJson(Map<String, dynamic> json) {
    // Memastikan akses yang aman ke properti 'sale'
    final saleJson = json['sale'];
    final transactionNo = saleJson != null ? saleJson['transaction_number'] : 'TRX-${json['sale_id']}';

    return SaleReturn(
      id: json['id'] ?? 0,
      saleId: (json['sale_id'] as num?)?.toInt() ?? 0,
      date: DateTime.tryParse(json['date'] ?? '') ?? DateTime.now(),
      total: (json['total'] as num?)?.toInt() ?? 0,
      status: json['status'] ?? 'PENDING',
      transactionNumber: transactionNo ?? 'N/A',
    );
  }
}

// --- Kelas Layanan API ---

class ApiService {
  final String _baseUrl = "http://localhost:8081/api/v1";

  Future<Map<String, String>> _getHeaders() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  // --- Fungsi Autentikasi ---
  Future<String?> login(String username, String password) async {
    final url = Uri.parse('$_baseUrl/auth/login');
    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'username': username, 'password': password}),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final token = data['token'];
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('token', token);
      await prefs.setString('userName', username);
      return token;
    } else {
      throw Exception(
          'Login failed: ${jsonDecode(response.body)['error'] ?? 'Unknown error'}');
    }
  }

  // --- Fungsi Produk ---
  Future<List<Product>> loadProducts() async {
    final url = Uri.parse('$_baseUrl/products');
    final response = await http.get(url, headers: await _getHeaders());

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      if (data['data'] != null) {
        return (data['data'] as List)
            .map((json) => Product.fromJson(json))
            .toList();
      }
      return [];
    } else if (response.statusCode == 401) {
      // Unauthorised, perlu login lagi
      await (await SharedPreferences.getInstance()).remove('token');
      throw Exception('Unauthorized. Please log in again.');
    } else {
      throw Exception('Failed to load products');
    }
  }

  // --- Fungsi Voucher ---
  Future<List<Voucher>> loadVouchers() async {
    final url = Uri.parse('$_baseUrl/vouchers');
    final response = await http.get(url, headers: await _getHeaders());

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      if (data['data'] != null) {
        return (data['data'] as List)
            .map((json) => Voucher.fromJson(json))
            .where((v) => v.active)
            .toList();
      }
      return [];
    }
    return [];
  }

  // --- Fungsi Checkout ---
  Future<String> checkout(
    String? customerName,
    String? voucherCode,
    int paidAmount,
    List<CartItem> items,
  ) async {
    final url = Uri.parse('$_baseUrl/kasir/sales');
    final payload = {
      'customer_name': customerName,
      'voucher_code': voucherCode,
      'paid_amount': paidAmount,
      'items': items
          .map((item) => {
                'product_id': item.id,
                'qty': item.qty,
              })
          .toList(),
    };

    final response = await http.post(
      url,
      headers: await _getHeaders(),
      body: jsonEncode(payload),
    );

    if (response.statusCode == 201) {
      final data = jsonDecode(response.body);
      return data['id']?.toString() ?? 'Unknown ID';
    } else {
      throw Exception(
          'Transaksi Gagal: ${jsonDecode(response.body)['message'] ?? 'Unknown Error'}');
    }
  }

  // --- Fungsi History Penjualan ---
  Future<List<SaleHistory>> fetchSalesHistory({
    String? startDate,
    String? endDate,
    int? limit,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final isFiltered = startDate != null || endDate != null;
    final endpoint = isFiltered ? "/history/sales" : "/history/sales/latest";
    final params = {
      if (startDate != null) 'start_date': startDate,
      if (endDate != null) 'end_date': endDate,
      'orderBy': 'date DESC',
      if (limit != null) 'size': limit.toString(),
      'page': '1',
    };
    final uri = Uri.parse('$_baseUrl$endpoint').replace(queryParameters: params);
    final response = await http.get(uri, headers: await _getHeaders());

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      if (data['data'] != null) {
        return (data['data'] as List)
            .map((json) => SaleHistory.fromJson(json))
            .toList();
      }
      return [];
    } else if (response.statusCode == 401) {
      await prefs.remove('token');
      throw Exception('Unauthorized. Please log in again.');
    } else {
      throw Exception(
          'Failed to load sales history: ${jsonDecode(response.body)['error'] ?? 'Unknown error'}');
    }
  }

  // --- Fungsi Detail Penjualan ---
  Future<SaleHistory> fetchSaleDetail(int saleId) async {
    final url = Uri.parse('$_baseUrl/history/sales/$saleId');
    final response = await http.get(url, headers: await _getHeaders());

    if (response.statusCode == 200) {
      return SaleHistory.fromJson(jsonDecode(response.body));
    } else {
      throw Exception('Failed to load sale detail');
    }
  }

  // --- Fungsi Daftar Retur ---
  Future<List<SaleReturn>> fetchSaleReturns({
    String? startDate,
    String? endDate,
    String? status,
  }) async {
    final params = {
      if (startDate != null) 'start_date': startDate,
      if (endDate != null) 'end_date': endDate,
      if (status != null && status.isNotEmpty) 'status': status,
      'orderBy': 'date DESC',
      'size': '10', // Membatasi ke 10 retur terakhir
      'page': '1',
    };
    final uri =
        Uri.parse('$_baseUrl/kasir/sale-returns').replace(queryParameters: params);
    final response = await http.get(uri, headers: await _getHeaders());

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      if (data['data'] != null) {
        return (data['data'] as List)
            .map((json) => SaleReturn.fromJson(json))
            .toList();
      }
      return [];
    } else {
      throw Exception('Failed to load sales returns');
    }
  }

  // --- Fungsi Submit Retur ---
  Future<void> submitReturn(
      int saleId, List<Map<String, dynamic>> items, String notes) async {
    final url = Uri.parse('$_baseUrl/kasir/sale-returns');
    final payload = {
      'sale_id': saleId,
      'notes': notes,
      'items': items,
    };

    final response = await http.post(
      url,
      headers: await _getHeaders(),
      body: jsonEncode(payload),
    );

    if (response.statusCode != 201) {
      throw Exception(
          'Gagal Submit Retur: ${jsonDecode(response.body)['message'] ?? 'Unknown Error'}');
    }
  }
}

// --- Fungsi Pembantu ---

final currencyFormatter = NumberFormat.currency(
  locale: 'id_ID',
  symbol: 'Rp',
  decimalDigits: 0,
);

String formatCurrency(int amount) {
  return currencyFormatter.format(amount);
}

String formatDate(DateTime date) {
  return DateFormat('dd/MM/yyyy HH:mm').format(date);
}

String formatReturnNumber(int id) {
  return id.toString().padLeft(6, '0');
}