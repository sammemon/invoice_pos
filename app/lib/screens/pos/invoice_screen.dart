import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:printing/printing.dart';
import '../../core/theme/app_theme.dart';
import '../../providers/auth_provider.dart';
import '../../services/pdf_service.dart';
import '../../providers/sale_provider.dart';

class InvoiceScreen extends ConsumerStatefulWidget {
  final String saleId;
  const InvoiceScreen({super.key, required this.saleId});
  @override
  ConsumerState<InvoiceScreen> createState() => _InvoiceScreenState();
}

class _InvoiceScreenState extends ConsumerState<InvoiceScreen> {
  Uint8List? _pdfBytes;
  bool _generating = false;

  @override
  void initState() {
    super.initState();
    _generatePdf();
  }

  Future<void> _generatePdf() async {
    setState(() => _generating = true);
    try {
      final pos   = ref.read(posProvider);
      final user  = ref.read(authProvider).user;
      final bytes = await PdfService.generateInvoice(
        saleId: widget.saleId,
        shopName: user?.shopName ?? 'My Shop',
        shopPhone: user?.phone ?? '',
        shopAddress: user?.address ?? '',
        customerName: pos.customerName ?? 'Walk-in Customer',
        items: pos.cart,
        subTotal: pos.subTotal,
        discountAmount: pos.discountAmount,
        taxAmount: pos.taxAmount,
        grandTotal: pos.grandTotal,
        paymentMethod: pos.paymentMethod,
        invoiceDate: DateTime.now(),
      );
      if (mounted) setState(() => _pdfBytes = bytes);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('PDF error: $e')));
    } finally {
      if (mounted) setState(() => _generating = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Invoice'),
      leading: IconButton(icon: const Icon(Icons.close_rounded),
          onPressed: () => context.go('/pos')),
      actions: [
        if (_pdfBytes != null) ...[
          IconButton(icon: const Icon(Icons.print_rounded),
              onPressed: () => Printing.layoutPdf(onLayout: (_) async => _pdfBytes!)),
          IconButton(icon: const Icon(Icons.share_rounded),
              onPressed: () => Printing.sharePdf(bytes: _pdfBytes!, filename: 'invoice_${widget.saleId}.pdf')),
        ],
        IconButton(icon: const Icon(Icons.home_rounded),
            onPressed: () => context.go('/dashboard')),
      ],
    ),
    body: _generating
        ? const Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Generating invoice...'),
          ]))
        : _pdfBytes != null
        ? PdfPreview(
            build: (_) async => _pdfBytes!,
            allowPrinting: true, allowSharing: true,
            canChangePageFormat: false,
          )
        : Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            const Icon(Icons.check_circle_rounded, size: 72, color: AppTheme.success),
            const SizedBox(height: 16),
            const Text('Sale Completed!', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text('Invoice ID: ${widget.saleId}', style: const TextStyle(color: Colors.grey)),
            const SizedBox(height: 24),
            ElevatedButton(onPressed: () => context.go('/pos'), child: const Text('New Sale')),
          ])),
  );
}
