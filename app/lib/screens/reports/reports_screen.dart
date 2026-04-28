import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:printing/printing.dart';
import '../../core/network/api_client.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/helpers.dart';
import '../../services/pdf_service.dart';
import '../../providers/auth_provider.dart';

final _salesSummaryProvider = FutureProvider.autoDispose.family<List<Map<String, dynamic>>, Map<String, String>>((ref, params) async {
  final res = await ApiClient.instance.get('/reports/sales-summary', params: params);
  return List<Map<String, dynamic>>.from(res.data['data'] ?? []);
});

final _topProductsProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final res = await ApiClient.instance.get('/reports/top-products');
  return List<Map<String, dynamic>>.from(res.data['data'] ?? []);
});

class ReportsScreen extends ConsumerStatefulWidget {
  const ReportsScreen({super.key});
  @override
  ConsumerState<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends ConsumerState<ReportsScreen> with SingleTickerProviderStateMixin {
  late TabController _tab;
  DateTime _from = Helpers.startOfMonth();
  DateTime _to   = Helpers.endOfMonth();

  @override
  void initState() { super.initState(); _tab = TabController(length: 3, vsync: this); }
  @override
  void dispose() { _tab.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final params = {'startDate': _from.toIso8601String(), 'endDate': _to.toIso8601String(), 'groupBy': 'day'};
    final summaryAsync = ref.watch(_salesSummaryProvider(params));
    final topAsync     = ref.watch(_topProductsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Reports & Analytics'),
        bottom: TabBar(controller: _tab, tabs: const [
          Tab(text: 'Sales'), Tab(text: 'Top Products'), Tab(text: 'Export'),
        ]),
        actions: [
          IconButton(icon: const Icon(Icons.date_range_rounded), onPressed: _pickDateRange),
        ],
      ),
      body: TabBarView(controller: _tab, children: [
        // ─── Sales ────────────────────────────────────────
        summaryAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => _ErrorWidget(e.toString(), onRetry: () => ref.invalidate(_salesSummaryProvider)),
          data: (data) => data.isEmpty
              ? const Center(child: Text('No sales data for this period'))
              : _SalesTab(data: data, from: _from, to: _to),
        ),
        // ─── Top Products ─────────────────────────────────
        topAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => _ErrorWidget(e.toString(), onRetry: () => ref.invalidate(_topProductsProvider)),
          data: (data) => _TopProductsTab(data: data),
        ),
        // ─── Export ───────────────────────────────────────
        _ExportTab(from: _from, to: _to, onExport: _exportPdf),
      ]),
    );
  }

  Future<void> _pickDateRange() async {
    final range = await showDateRangePicker(context: context,
        firstDate: DateTime(2020), lastDate: DateTime.now(),
        initialDateRange: DateTimeRange(start: _from, end: _to));
    if (range != null) setState(() { _from = range.start; _to = range.end; });
  }

  Future<void> _exportPdf() async {
    final user = ref.read(authProvider).user;
    final params = {'startDate': _from.toIso8601String(), 'endDate': _to.toIso8601String()};
    try {
      final res = await ApiClient.instance.get('/sales', params: {...params, 'limit': '1000'});
      final sales = List<Map<String, dynamic>>.from(res.data['data'] ?? []);
      final total = sales.fold(0.0, (s, i) => s + (i['grandTotal'] ?? 0));
      final profit = sales.fold(0.0, (s, i) {
        final items = (i['items'] as List? ?? []);
        final cost = items.fold(0.0, (c, item) => c + (item['purchasePrice'] ?? 0) * (item['quantity'] ?? 1));
        return s + (i['grandTotal'] ?? 0) - cost;
      });
      final bytes = await PdfService.generateSalesReport(
          shopName: user?.shopName ?? 'My Shop', sales: sales,
          from: _from, to: _to, totalRevenue: total, totalProfit: profit);
      await Printing.sharePdf(bytes: bytes, filename: 'sales_report.pdf');
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Export failed: $e')));
    }
  }
}

class _SalesTab extends StatelessWidget {
  final List<Map<String, dynamic>> data;
  final DateTime from, to;
  const _SalesTab({required this.data, required this.from, required this.to});

  @override
  Widget build(BuildContext context) {
    final spots = data.asMap().entries.map((e) =>
        FlSpot(e.key.toDouble(), (e.value['totalSales'] ?? 0).toDouble())).toList();
    final maxY = spots.map((s) => s.y).reduce((a, b) => a > b ? a : b) * 1.2;
    final totalSales  = data.fold(0.0, (s, i) => s + (i['totalSales'] ?? 0));
    final totalProfit = data.fold(0.0, (s, i) => s + (i['totalProfit'] ?? 0));

    return ListView(padding: const EdgeInsets.all(16), children: [
      Row(children: [
        Expanded(child: _MetricCard('Revenue', Helpers.formatCurrency(totalSales), Icons.trending_up_rounded, AppTheme.primary)),
        const SizedBox(width: 12),
        Expanded(child: _MetricCard('Profit', Helpers.formatCurrency(totalProfit), Icons.savings_rounded, AppTheme.success)),
      ]),
      const SizedBox(height: 20),
      const Text('Sales Trend', style: TextStyle(fontWeight: FontWeight.bold)),
      const SizedBox(height: 12),
      SizedBox(height: 200,
        child: LineChart(LineChartData(
          gridData: const FlGridData(show: false),
          titlesData: const FlTitlesData(show: false),
          borderData: FlBorderData(show: false),
          lineBarsData: [LineChartBarData(
            spots: spots, isCurved: true,
            color: AppTheme.primary, barWidth: 3,
            belowBarData: BarAreaData(show: true, color: AppTheme.primary.withAlpha(30)),
            dotData: const FlDotData(show: false),
          )],
          minY: 0, maxY: maxY > 0 ? maxY : 100,
        )),
      ),
    ]);
  }
}

class _MetricCard extends StatelessWidget {
  final String label, value;
  final IconData icon;
  final Color color;
  const _MetricCard(this.label, this.value, this.icon, this.color);

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text(label, style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
        Icon(icon, color: color, size: 18),
      ]),
      const SizedBox(height: 4),
      Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color)),
    ])),
  );
}

class _TopProductsTab extends StatelessWidget {
  final List<Map<String, dynamic>> data;
  const _TopProductsTab({required this.data});

  @override
  Widget build(BuildContext context) {
    if (data.isEmpty) return const Center(child: Text('No data'));
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: data.length,
      itemBuilder: (_, i) {
        final p = data[i];
        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            leading: CircleAvatar(backgroundColor: AppTheme.primary.withAlpha(20),
                child: Text('${i + 1}', style: const TextStyle(color: AppTheme.primary, fontWeight: FontWeight.bold))),
            title: Text(p['productName'] ?? '', style: const TextStyle(fontWeight: FontWeight.w600)),
            subtitle: Text('Sold: ${p['totalQty']} units'),
            trailing: Text(Helpers.formatCurrency((p['totalRevenue'] ?? 0).toDouble()),
                style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.primary)),
          ),
        );
      },
    );
  }
}

class _ExportTab extends StatelessWidget {
  final DateTime from, to;
  final VoidCallback onExport;
  const _ExportTab({required this.from, required this.to, required this.onExport});

  @override
  Widget build(BuildContext context) => ListView(padding: const EdgeInsets.all(20), children: [
    const Icon(Icons.picture_as_pdf_rounded, size: 64, color: AppTheme.error),
    const SizedBox(height: 16),
    Text('Export Period', style: Theme.of(context).textTheme.titleMedium),
    const SizedBox(height: 8),
    Text('${Helpers.formatDate(from)} — ${Helpers.formatDate(to)}',
        style: const TextStyle(color: Colors.grey)),
    const SizedBox(height: 32),
    ElevatedButton.icon(
      onPressed: onExport,
      icon: const Icon(Icons.download_rounded),
      label: const Text('Export Sales Report PDF'),
    ),
  ]);
}

class _ErrorWidget extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorWidget(this.message, {required this.onRetry});

  @override
  Widget build(BuildContext context) => Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
    const Icon(Icons.error_outline, size: 48, color: Colors.grey),
    const SizedBox(height: 12),
    Text(message, textAlign: TextAlign.center, style: const TextStyle(color: Colors.grey)),
    const SizedBox(height: 16),
    ElevatedButton(onPressed: onRetry, child: const Text('Retry')),
  ]));
}
