// file: lib/screens/retur_screen.dart

import 'package:flutter/material.dart';
import '../../services/cashier_service.dart';
import 'package:intl/intl.dart';

class ReturScreen extends StatefulWidget {
  const ReturScreen({super.key});

  @override
  State<ReturScreen> createState() => _ReturScreenState();
}

class _ReturScreenState extends State<ReturScreen> {
  final ApiService _apiService = ApiService();
  String _userName = 'Kasir';

  // State History Penjualan
  List<SaleHistory> _salesHistory = [];
  bool _loadingHistory = true;
  DateTime? _fromDate;
  DateTime? _toDate;

  // State Daftar Retur
  List<SaleReturn> _saleReturns = [];
  bool _loadingReturns = false;
  DateTime? _returnFromDate;
  DateTime? _returnToDate;
  String? _returnStatusFilter; // 'PENDING', 'APPROVED', 'REJECTED', atau null/kosong

  // State Modal Retur
  bool _showModal = false;
  SaleHistory? _selectedSale;
  final List<TextEditingController> _qtyControllers = [];
  final List<TextEditingController> _reasonControllers = [];
  final TextEditingController _notesController = TextEditingController();
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    // Ambil history penjualan 10 terakhir
    await _fetchSalesHistory();
    // Ambil daftar retur 10 terakhir
    await _fetchSaleReturns();
  }

  // --- Logic History Penjualan ---
  Future<void> _fetchSalesHistory() async {
    setState(() => _loadingHistory = true);
    try {
      final loadedHistory = await _apiService.fetchSalesHistory(
        startDate: _fromDate != null
            ? DateFormat('yyyy-MM-dd').format(_fromDate!)
            : null,
        endDate: _toDate != null
            ? DateFormat('yyyy-MM-dd').format(_toDate!)
            : null,
        limit: (_fromDate == null && _toDate == null) ? 10 : null,
      );
      setState(() {
        _salesHistory = loadedHistory;
      });
    } catch (e) {
      _showSnackbar(context, e.toString(), isError: true);
      setState(() => _salesHistory = []);
    } finally {
      setState(() => _loadingHistory = false);
    }
  }

  void _resetHistoryFilter() {
    setState(() {
      _fromDate = null;
      _toDate = null;
    });
    _fetchSalesHistory();
  }

  // --- Logic Daftar Retur ---
  Future<void> _fetchSaleReturns() async {
    setState(() => _loadingReturns = true);
    try {
      final loadedReturns = await _apiService.fetchSaleReturns(
        startDate: _returnFromDate != null
            ? DateFormat('yyyy-MM-dd').format(_returnFromDate!)
            : null,
        endDate: _returnToDate != null
            ? DateFormat('yyyy-MM-dd').format(_returnToDate!)
            : null,
        status: _returnStatusFilter,
      );
      setState(() {
        _saleReturns = loadedReturns;
      });
    } catch (e) {
      _showSnackbar(context, e.toString(), isError: true);
      setState(() => _saleReturns = []);
    } finally {
      setState(() => _loadingReturns = false);
    }
  }

  void _resetReturnFilter() {
    setState(() {
      _returnFromDate = null;
      _returnToDate = null;
      _returnStatusFilter = null;
    });
    _fetchSaleReturns();
  }

  // --- Logic Modal Retur ---
  Future<void> _openReturnModal(int saleId) async {
    try {
      final saleDetail = await _apiService.fetchSaleDetail(saleId);
      setState(() {
        _selectedSale = saleDetail;
        _notesController.text = '';
        _qtyControllers.clear();
        _reasonControllers.clear();

        for (var item in saleDetail.items) {
          _qtyControllers
              .add(TextEditingController(text: '0'));
          _reasonControllers.add(TextEditingController());
        }

        _showModal = true;
      });
    } catch (e) {
      _showSnackbar(context, 'Gagal memuat detail penjualan: $e',
          isError: true);
    }
  }

  void _closeModal() {
    setState(() {
      _showModal = false;
      _selectedSale = null;
    });
    // Bersihkan controller setelah modal ditutup
    for (var controller in _qtyControllers) {
      controller.dispose();
    }
    for (var controller in _reasonControllers) {
      controller.dispose();
    }
    _qtyControllers.clear();
    _reasonControllers.clear();
    _notesController.clear();
  }

  bool get _hasValidItems {
    if (_selectedSale == null) return false;
    for (int i = 0; i < _selectedSale!.items.length; i++) {
      final qtyText = _qtyControllers[i].text;
      final qty = int.tryParse(qtyText) ?? 0;
      final reason = _reasonControllers[i].text.trim();
      if (qty > 0 && reason.isNotEmpty) {
        return true;
      }
    }
    return false;
  }

  Future<void> _submitReturn() async {
    if (!_hasValidItems) {
      _showSnackbar(
          context, 'Harap isi kuantitas retur (>0) dan alasan yang valid.',
          isError: true);
      return;
    }

    setState(() => _submitting = true);

    try {
      final List<Map<String, dynamic>> items = [];
      for (int i = 0; i < _selectedSale!.items.length; i++) {
        final item = _selectedSale!.items[i];
        final qtyText = _qtyControllers[i].text;
        final qty = int.tryParse(qtyText) ?? 0;
        final reason = _reasonControllers[i].text.trim();

        if (qty > 0 && reason.isNotEmpty) {
          items.add({
            'product_id': item.productID,
            'qty': qty,
            'reason': reason,
          });
        }
      }

      await _apiService.submitReturn(
        _selectedSale!.id,
        items,
        _notesController.text,
      );

      _showSnackbar(context, 'Retur berhasil diajukan! Menunggu persetujuan.');
      _closeModal();
      await _fetchSaleReturns(); // Refresh daftar retur
    } catch (e) {
      _showSnackbar(context, e.toString(), isError: true);
    } finally {
      setState(() => _submitting = false);
    }
  }

  // --- Fungsi Pembantu UI ---

  void _showSnackbar(BuildContext context, String message,
      {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : Colors.green,
      ),
    );
  }

  String _getStatusText(String status) {
    switch (status) {
      case 'PENDING':
        return 'Pending';
      case 'APPROVED':
        return 'Disetujui';
      case 'REJECTED':
        return 'Ditolak';
      default:
        return 'N/A';
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'PENDING':
        return Colors.orange;
      case 'APPROVED':
        return Colors.green;
      case 'REJECTED':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Retur Penjualan'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Retur Penjualan',
                  style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
                ),
                const Divider(height: 30),
                _buildSalesHistorySection(),
                const Divider(height: 30),
                _buildReturnsListSection(),
              ],
            ),
          ),
          if (_showModal) _buildReturnModal(context),
        ],
      ),
    );
  }

  // --- Widget Bagian-bagian ---

  Widget _buildSalesHistorySection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'History Penjualan (untuk Retur)',
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 10),
        // Filter Tanggal
        Container(
          padding: const EdgeInsets.all(12.0),
          decoration: BoxDecoration(
            color: Colors.grey[200],
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildDateFilter('Dari Tanggal', _fromDate, (date) {
                    setState(() => _fromDate = date);
                  }),
                  _buildDateFilter('Sampai Tanggal', _toDate, (date) {
                    setState(() => _toDate = date);
                  }),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  ElevatedButton(
                    onPressed: _loadingHistory ? null : _fetchSalesHistory,
                    child: Text(_loadingHistory ? 'Loading...' : 'Filter'),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton(
                    onPressed: _resetHistoryFilter,
                    child: const Text('Reset (10 Terakhir)'),
                  ),
                ],
              ),
              if (_fromDate != null || _toDate != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8.0),
                  child: Text(
                      'Filter aktif: ${(_fromDate != null ? DateFormat('dd-MM-yyyy').format(_fromDate!) : 'N/A')} s/d ${(_toDate != null ? DateFormat('dd-MM-yyyy').format(_toDate!) : 'N/A')}',
                      style: const TextStyle(fontSize: 12)),
                ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        // Tabel History
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            columns: const [
              DataColumn(label: Text('Tanggal')),
              DataColumn(label: Text('Nomor Transaksi')),
              DataColumn(label: Text('Total')),
              DataColumn(label: Text('Aksi')),
            ],
            rows: _loadingHistory
                ? [
                    const DataRow(cells: [
                      DataCell(Text('Loading...')),
                      DataCell(SizedBox()),
                      DataCell(SizedBox()),
                      DataCell(SizedBox()),
                    ])
                  ]
                : _salesHistory.isEmpty
                    ? [
                        const DataRow(cells: [
                          DataCell(Text('Tidak ada data penjualan.')),
                          DataCell(SizedBox()),
                          DataCell(SizedBox()),
                          DataCell(SizedBox()),
                        ])
                      ]
                    : _salesHistory
                        .map(
                          (sale) => DataRow(
                            cells: [
                              DataCell(Text(formatDate(sale.date))),
                              DataCell(Text(sale.transactionNumber)),
                              DataCell(Text(formatCurrency(sale.total))),
                              DataCell(
                                ElevatedButton(
                                  onPressed: () => _openReturnModal(sale.id),
                                  style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.green,
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.all(4),
                                      minimumSize: const Size(40, 20)),
                                  child: const Text('ADD',
                                      style: TextStyle(fontSize: 12)),
                                ),
                              ),
                            ],
                          ),
                        )
                        .toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildReturnsListSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Daftar Retur Saya',
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 10),
        // Filter Retur
        Container(
          padding: const EdgeInsets.all(12.0),
          decoration: BoxDecoration(
            color: Colors.grey[200],
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildDateFilter('Dari Tanggal', _returnFromDate, (date) {
                    setState(() => _returnFromDate = date);
                  }),
                  _buildDateFilter('Sampai Tanggal', _returnToDate, (date) {
                    setState(() => _returnToDate = date);
                  }),
                ],
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<String?>(
                decoration: const InputDecoration(
                    labelText: 'Status', border: OutlineInputBorder(), isDense: true),
                value: _returnStatusFilter,
                hint: const Text('Semua'),
                items: const [
                  DropdownMenuItem(value: null, child: Text('Semua')),
                  DropdownMenuItem(value: 'PENDING', child: Text('Pending')),
                  DropdownMenuItem(value: 'APPROVED', child: Text('Approved')),
                  DropdownMenuItem(value: 'REJECTED', child: Text('Rejected')),
                ],
                onChanged: (value) {
                  setState(() => _returnStatusFilter = value);
                },
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  ElevatedButton(
                    onPressed: _loadingReturns ? null : _fetchSaleReturns,
                    child: Text(_loadingReturns ? 'Loading...' : 'Filter'),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton(
                    onPressed: _resetReturnFilter,
                    child: const Text('Reset (10 Terakhir)'),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        // Tabel Daftar Retur
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            columns: const [
              DataColumn(label: Text('Return No.')),
              DataColumn(label: Text('No. Transaksi')),
              DataColumn(label: Text('Tanggal')),
              DataColumn(label: Text('Total')),
              DataColumn(label: Text('Status')),
            ],
            rows: _loadingReturns
                ? [
                    const DataRow(cells: [
                      DataCell(Text('Loading...')),
                      DataCell(SizedBox()),
                      DataCell(SizedBox()),
                      DataCell(SizedBox()),
                      DataCell(SizedBox()),
                    ])
                  ]
                : _saleReturns.isEmpty
                    ? [
                        const DataRow(cells: [
                          DataCell(Text('Tidak ada retur yang dibuat.')),
                          DataCell(SizedBox()),
                          DataCell(SizedBox()),
                          DataCell(SizedBox()),
                          DataCell(SizedBox()),
                        ])
                      ]
                    : _saleReturns
                        .map(
                          (ret) => DataRow(
                            cells: [
                              DataCell(Text('RTN-${formatReturnNumber(ret.id)}')),
                              DataCell(Text(ret.transactionNumber)),
                              DataCell(Text(formatDate(ret.date))),
                              DataCell(Text(formatCurrency(ret.total))),
                              DataCell(
                                Chip(
                                  label: Text(_getStatusText(ret.status),
                                      style:
                                          const TextStyle(color: Colors.white)),
                                  backgroundColor: _getStatusColor(ret.status),
                                ),
                              ),
                            ],
                          ),
                        )
                        .toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildDateFilter(
      String label, DateTime? date, Function(DateTime) onSelect) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 12)),
        InkWell(
          onTap: () async {
            final pickedDate = await showDatePicker(
              context: context,
              initialDate: date ?? DateTime.now(),
              firstDate: DateTime(2020),
              lastDate: DateTime(2030),
            );
            if (pickedDate != null) {
              onSelect(pickedDate);
            }
          },
          child: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
                border: Border.all(color: Colors.grey),
                borderRadius: BorderRadius.circular(5)),
            child: Text(
              date == null ? 'Pilih Tanggal' : DateFormat('dd-MM-yyyy').format(date),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildReturnModal(BuildContext context) {
    if (_selectedSale == null) return const SizedBox.shrink();

    return Container(
      color: Colors.black54,
      alignment: Alignment.center,
      child: Material(
        color: Colors.transparent,
        child: Container(
          width: MediaQuery.of(context).size.width * 0.8,
          constraints: const BoxConstraints(maxHeight: 600, maxWidth: 900),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
          ),
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Buat Retur Penjualan',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              const Divider(),
              // Detail Transaksi
              Container(
                padding: const EdgeInsets.all(8),
                color: Colors.grey[100],
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                        'Nomor Transaksi: ${_selectedSale!.transactionNumber}',
                        style: const TextStyle(fontWeight: FontWeight.bold)),
                    Text(
                        'Tanggal: ${formatDate(_selectedSale!.date)}'),
                    Text('Total: ${formatCurrency(_selectedSale!.total)}'),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              const Text('Items untuk Diretur',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    children: _selectedSale!.items.asMap().entries.map((entry) {
                      final index = entry.key;
                      final item = entry.value;
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8.0),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              flex: 3,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(item.productName,
                                      style: const TextStyle(fontWeight: FontWeight.bold)),
                                  Text(
                                      'Qty Original: ${item.qty} | Harga: ${formatCurrency(item.price)}',
                                      style: const TextStyle(fontSize: 12, color: Colors.grey)),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              flex: 1,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('Qty Retur', style: TextStyle(fontSize: 12)),
                                  TextField(
                                    controller: _qtyControllers[index],
                                    keyboardType: TextInputType.number,
                                    decoration: InputDecoration(
                                      border: const OutlineInputBorder(),
                                      isDense: true,
                                      contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                                      constraints: BoxConstraints.loose(const Size.fromWidth(80)),
                                    ),
                                    onChanged: (value) {
                                      int? newQty = int.tryParse(value);
                                      if (newQty != null) {
                                        if (newQty > item.qty) {
                                          _qtyControllers[index].text = item.qty.toString();
                                          _showSnackbar(context, 'Qty Retur tidak boleh melebihi Qty Original: ${item.qty}', isError: true);
                                        } else if (newQty < 0) {
                                          _qtyControllers[index].text = '0';
                                        }
                                      }
                                      setState(() {}); // Trigger perubahan tombol submit
                                    },
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              flex: 3,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('Alasan', style: TextStyle(fontSize: 12)),
                                  TextField(
                                    controller: _reasonControllers[index],
                                    maxLines: 2,
                                    decoration: const InputDecoration(
                                      hintText: 'Masukkan alasan retur',
                                      border: OutlineInputBorder(),
                                      isDense: true,
                                      contentPadding: EdgeInsets.all(8),
                                    ),
                                    onChanged: (_) => setState(() {}), // Trigger perubahan tombol submit
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              // Catatan Tambahan
              const Text('Catatan Tambahan', style: TextStyle(fontSize: 12)),
              TextField(
                controller: _notesController,
                maxLines: 3,
                decoration: const InputDecoration(
                  hintText: 'Catatan opsional untuk retur ini',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
              ),
              const SizedBox(height: 20),
              // Tombol Aksi
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  OutlinedButton(
                    onPressed: _closeModal,
                    child: const Text('Batal'),
                  ),
                  const SizedBox(width: 10),
                  ElevatedButton(
                    onPressed:
                        _submitting || !_hasValidItems ? null : _submitReturn,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                    ),
                    child: Text(_submitting ? 'Menyimpan...' : 'Submit Retur'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}