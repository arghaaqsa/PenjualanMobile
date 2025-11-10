import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dio/dio.dart';  // Import Dio langsung buat instance auth

class DashboardCashier extends StatefulWidget {
  const DashboardCashier({super.key});

  @override
  State<DashboardCashier> createState() => _DashboardCashierState();
}

class _DashboardCashierState extends State<DashboardCashier> {
  String userName = 'Kasir';
  List<dynamic> salesHistory = [];
  bool loadingHistory = true;
  DateTime? fromDate;
  DateTime? toDate;
  bool showDetailsModal = false;
  dynamic selectedSale;  // Data transaksi detail

  @override
  void initState() {
    super.initState();
    _loadUserName();
    _fetchDashboardData();
  }

  // Load userName dari SharedPreferences
  Future<void> _loadUserName() async {
    final prefs = await SharedPreferences.getInstance();
    final savedName = prefs.getString('userName') ?? 'Kasir';
    setState(() {
      userName = savedName;
    });
  }

  // Fetch data history penjualan (FIX: IP laptop-mu untuk HP fisik)
  Future<void> _fetchDashboardData() async {
    setState(() => loadingHistory = true);

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');
      if (token == null) {
        _showError('Token tidak ditemukan. Login ulang.');
        return;
      }

      final dio = Dio();  // Instance baru buat auth
      dio.options.headers['Authorization'] = 'Bearer $token';  // Header auth
      dio.options.baseUrl = 'http://localhost:8081/api/v1';  // IP laptop-mu

      final params = <String, dynamic>{
        'page': 1,
        'size': 10,
        'orderBy': 'date DESC',
      };

      if (fromDate != null) {
        params['start_date'] = DateFormat('yyyy-MM-dd').format(fromDate!);
      }
      if (toDate != null) {
        params['end_date'] = DateFormat('yyyy-MM-dd').format(toDate!);
      }

      debugPrint('Request params: $params');  // Debug log

      // Endpoint: /history/sales atau /history/sales/latest
      final endpoint = fromDate != null || toDate != null ? '/history/sales' : '/history/sales/latest';
      final response = await dio.get(endpoint, queryParameters: params);

      debugPrint('Response status: ${response.statusCode}');  // Debug
      debugPrint('Response data: ${response.data}');  // Debug full response

      if (response.statusCode == 200) {
        final data = response.data['data'] ?? [];
        setState(() {
          salesHistory = data.map((sale) {
            final total = (sale['Total'] as num?)?.toDouble() ?? 0.0;  // FIX: Safe cast int to double
            final paid = (sale['Paid'] as num?)?.toDouble() ?? 0.0;
            final change = (sale['Change'] as num?)?.toDouble() ?? paid - total;
            return {
              'ID': sale['ID'],
              'Date': sale['Date'],
              'transaction_number': sale['transaction_number'],
              'Total': total,
              'Paid': paid,
              'Change': change,
              'Customer': sale['Customer'] ?? {'name': 'N/A'},
              'Items': sale['Items'] ?? [],
            };
          }).toList();
        });
      } else {
        _showError('Gagal mengambil data: ${response.statusCode} - ${response.data['message'] ?? 'Unknown error'}');
      }
    } catch (error) {
      debugPrint('Error fetch: $error');  // Debug error
      if (error is DioException) {
        _showError('Error API: ${error.message} - Status: ${error.response?.statusCode}');
      } else {
        _showError('Kesalahan jaringan atau server tidak tersedia.');
      }
    } finally {
      setState(() => loadingHistory = false);
    }
  }

  // Reset filter
  void _resetFilter() {
    setState(() {
      fromDate = null;
      toDate = null;
    });
    _fetchDashboardData();
  }

  // Format date (ID locale)
  String _formatDate(String? dateStr) {
    if (dateStr == null) return 'N/A';
    try {
      final date = DateTime.parse(dateStr);
      return DateFormat('dd/MM/yyyy', 'id_ID').format(date);
    } catch (e) {
      return dateStr.split('T')[0];  // Fallback slice
    }
  }

  // Format currency (Rp)
  String _formatCurrency(double amount) {
    final formatter = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);
    return formatter.format(amount);
  }

  // Print PDF (buka/download dari backend) - FIX: IP laptop-mu
  Future<void> _printPDF(int saleId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');
      final urlString = 'http://localhost:8081/api/v1/history/sales/$saleId/pdf';  // IP laptop-mu
      final dio = Dio();
      dio.options.headers['Authorization'] = 'Bearer $token';

      // Coba launch langsung (buka di browser/PDF viewer)
      final url = Uri.parse(urlString);
      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
      } else {
        _showError('Gagal membuka PDF');
      }
    } catch (e) {
      _showError('Error printing PDF: $e');
    }
  }

  // View detail transaksi (FIX: IP laptop-mu & safe cast)
  Future<void> _viewDetails(int saleId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');
      if (token == null) {
        _showError('Token tidak ditemukan.');
        return;
      }

      final dio = Dio();
      dio.options.headers['Authorization'] = 'Bearer $token';
      dio.options.baseUrl = 'http://localhost:8081/api/v1';  // IP laptop-mu

      final response = await dio.get('/history/sales/$saleId');

      debugPrint('Detail response status: ${response.statusCode}');  // Debug
      debugPrint('Detail response data: ${response.data}');  // Debug

      if (response.statusCode == 200) {
        final data = response.data;
        final total = (data['Total'] as num?)?.toDouble() ?? 0.0;  // FIX: Safe cast
        final paid = (data['Paid'] as num?)?.toDouble() ?? 0.0;
        final change = (data['Change'] as num?)?.toDouble() ?? paid - total;
        setState(() {
          selectedSale = {
            'ID': data['ID'],
            'Date': data['Date'],
            'transaction_number': data['transaction_number'],
            'Total': total,
            'Paid': paid,
            'Change': change,
            'Customer': data['Customer'] ?? {'name': 'N/A'},
            'Items': (data['Items'] as List?)?.map((item) {
              final qty = (item['Qty'] as num?)?.toDouble() ?? 0.0;  // FIX: Safe cast item
              final price = (item['Price'] as num?)?.toDouble() ?? 0.0;
              return {
                'Product': item['Product'] ?? {'name': 'N/A'},
                'Qty': qty,
                'Price': price,
              };
            }).toList() ?? [],
          };
        });
        _showDetailsModal();
      } else {
        _showError('Gagal memuat detail: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Error view details: $e');  // Debug
      if (e is DioException) {
        _showError('Error API detail: ${e.message}');
      } else {
        _showError('Gagal memuat detail: $e');
      }
    }
  }

  // Show modal detail (tetep sama)
  void _showDetailsModal() {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          width: double.infinity,
          constraints: const BoxConstraints(maxWidth: 400, maxHeight: 600),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AppBar(
                title: const Text('Detail Transaksi'),
                actions: [
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (selectedSale != null) ...[
                        _buildDetailRow('Nomor Transaksi', selectedSale!['transaction_number'] ?? 'TRX-${selectedSale!['ID']}'),
                        _buildDetailRow('Tanggal', _formatDate(selectedSale!['Date'])),
                        _buildDetailRow('Total', _formatCurrency(selectedSale!['Total'] ?? 0.0)),
                        _buildDetailRow('Uang Bayar', _formatCurrency(selectedSale!['Paid'] ?? 0.0)),
                        _buildDetailRow('Kembalian', _formatCurrency(selectedSale!['Change'] ?? 0.0)),
                        _buildDetailRow('Customer', selectedSale!['Customer']['name'] ?? 'N/A'),
                        const SizedBox(height: 16),
                        const Text('Daftar Barang', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 8),
                        ListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: (selectedSale!['Items'] as List).length,
                          itemBuilder: (context, index) {
                            final item = selectedSale!['Items'][index];
                            final subtotal = (item['Qty'] ?? 0.0) * (item['Price'] ?? 0.0);  // FIX: Double safe
                            return ListTile(
                              title: Text(item['Product']['name'] ?? 'N/A'),
                              subtitle: Text('Qty: ${item['Qty']} | Harga: ${_formatCurrency(item['Price'] ?? 0.0)}'),
                              trailing: Text(_formatCurrency(subtotal)),
                            );
                          },
                        ),
                      ] else ...[
                        const Padding(
                          padding: EdgeInsets.all(16),
                          child: Text('Data tidak ditemukan.'),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 120, child: Text('$label: ', style: const TextStyle(fontWeight: FontWeight.bold))),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Dashboard Kasir', style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF4F46E5),
        foregroundColor: Colors.white,
      ),
      body: RefreshIndicator(
        onRefresh: _fetchDashboardData,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Welcome
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Text(
                  'Selamat datang, $userName',
                  style: GoogleFonts.poppins(fontSize: 24, fontWeight: FontWeight.bold),
                ),
              ),
              // Filter
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Dari Tanggal', style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey)),
                                ElevatedButton.icon(
                                  onPressed: () async {
                                    final picked = await showDatePicker(
                                      context: context,
                                      initialDate: fromDate ?? DateTime.now(),
                                      firstDate: DateTime(2020),
                                      lastDate: DateTime.now(),
                                    );
                                    if (picked != null) {
                                      setState(() => fromDate = picked);
                                    }
                                  },
                                  icon: const Icon(Icons.calendar_today, size: 16),
                                  label: Text(fromDate == null ? 'Pilih Tanggal' : DateFormat('dd/MM/yyyy').format(fromDate!)),
                                  style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 40)),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Sampai Tanggal', style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey)),
                                ElevatedButton.icon(
                                  onPressed: () async {
                                    final picked = await showDatePicker(
                                      context: context,
                                      initialDate: toDate ?? DateTime.now(),
                                      firstDate: DateTime(2020),
                                      lastDate: DateTime.now(),
                                    );
                                    if (picked != null) {
                                      setState(() => toDate = picked);
                                    }
                                  },
                                  icon: const Icon(Icons.calendar_today, size: 16),
                                  label: Text(toDate == null ? 'Pilih Tanggal' : DateFormat('dd/MM/yyyy').format(toDate!)),
                                  style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 40)),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: loadingHistory ? null : _fetchDashboardData,
                              icon: const Icon(Icons.search),
                              label: Text(loadingHistory ? 'Loading...' : 'Filter'),
                              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF4F46E5)),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: _resetFilter,
                              icon: const Icon(Icons.refresh),
                              label: const Text('Reset (10 Terakhir)'),
                              style: ElevatedButton.styleFrom(backgroundColor: Colors.grey),
                            ),
                          ),
                        ],
                      ),
                      if (fromDate != null || toDate != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(
                            'Filter aktif: ${fromDate != null ? DateFormat('dd/MM/yyyy').format(fromDate!) : 'N/A'} s/d ${toDate != null ? DateFormat('dd/MM/yyyy').format(toDate!) : 'N/A'}',
                            style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              // History
              Text(
                'History Penjualan (${fromDate != null || toDate != null ? "Filtered" : "10 Terakhir"})',
                style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Card(
                child: loadingHistory
                    ? const Padding(
                        padding: EdgeInsets.all(32),
                        child: CircularProgressIndicator(),
                      )
                    : salesHistory.isEmpty
                        ? const Padding(
                            padding: EdgeInsets.all(32),
                            child: Text('Tidak ada data penjualan.', style: TextStyle(color: Colors.grey)),
                          )
                        : ListView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: salesHistory.length,
                            itemBuilder: (context, index) {
                              final sale = salesHistory[index];
                              return Card(
                                margin: const EdgeInsets.symmetric(vertical: 4),
                                child: ListTile(
                                  title: Text('No. Transaksi: ${sale['transaction_number'] ?? 'TRX-${sale['ID']}' }'),
                                  subtitle: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text('Tanggal: ${_formatDate(sale['Date'])}'),
                                      Text('Total: ${_formatCurrency(sale['Total'] ?? 0.0)}'),
                                    ],
                                  ),
                                  trailing: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      IconButton(
                                        icon: const Icon(Icons.picture_as_pdf, color: Color(0xFF4F46E5)),
                                        onPressed: () => _printPDF(sale['ID']),
                                        tooltip: 'Print PDF',
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.visibility, color: Color(0xFF4F46E5)),
                                        onPressed: () => _viewDetails(sale['ID']),
                                        tooltip: 'Lihat Detail',
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}