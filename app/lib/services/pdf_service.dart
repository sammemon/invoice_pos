import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../core/utils/helpers.dart';
import '../providers/sale_provider.dart';

class PdfService {
  static Future<Uint8List> generateInvoice({
    required String saleId,
    required String shopName,
    required String shopPhone,
    required String shopAddress,
    required String customerName,
    required List<CartItem> items,
    required double subTotal,
    required double discountAmount,
    required double taxAmount,
    required double grandTotal,
    required String paymentMethod,
    required DateTime invoiceDate,
  }) async {
    final pdf = pw.Document();
    pdf.addPage(pw.Page(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(32),
      build: (ctx) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          // Header
          pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
            pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
              pw.Text(shopName, style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold)),
              if (shopPhone.isNotEmpty) pw.Text(shopPhone, style: const pw.TextStyle(fontSize: 11)),
              if (shopAddress.isNotEmpty) pw.Text(shopAddress, style: const pw.TextStyle(fontSize: 11)),
            ]),
            pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.end, children: [
              pw.Text('INVOICE', style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold,
                  color: PdfColors.blue800)),
              pw.Text('# $saleId', style: const pw.TextStyle(fontSize: 11)),
              pw.Text(Helpers.formatDateTime(invoiceDate), style: const pw.TextStyle(fontSize: 11)),
            ]),
          ]),
          pw.SizedBox(height: 16),
          pw.Divider(color: PdfColors.blue800, thickness: 2),
          pw.SizedBox(height: 8),

          // Customer
          pw.Container(
            padding: const pw.EdgeInsets.all(10),
            decoration: pw.BoxDecoration(color: PdfColors.grey100, borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6))),
            child: pw.Row(children: [
              pw.Text('Bill To: ', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 12)),
              pw.Text(customerName, style: const pw.TextStyle(fontSize: 12)),
            ]),
          ),
          pw.SizedBox(height: 16),

          // Items table
          pw.Table(
            border: pw.TableBorder.all(color: PdfColors.grey300),
            columnWidths: {
              0: const pw.FlexColumnWidth(4),
              1: const pw.FlexColumnWidth(1),
              2: const pw.FlexColumnWidth(2),
              3: const pw.FlexColumnWidth(2),
            },
            children: [
              pw.TableRow(
                decoration: const pw.BoxDecoration(color: PdfColors.blue800),
                children: ['Item', 'Qty', 'Price', 'Total'].map((h) => pw.Padding(
                  padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                  child: pw.Text(h, style: pw.TextStyle(color: PdfColors.white, fontWeight: pw.FontWeight.bold, fontSize: 11)),
                )).toList(),
              ),
              ...items.map((item) => pw.TableRow(children: [
                pw.Padding(padding: const pw.EdgeInsets.all(6),
                    child: pw.Text(item.product.name, style: const pw.TextStyle(fontSize: 11))),
                pw.Padding(padding: const pw.EdgeInsets.all(6),
                    child: pw.Text('${item.quantity}', style: const pw.TextStyle(fontSize: 11))),
                pw.Padding(padding: const pw.EdgeInsets.all(6),
                    child: pw.Text(Helpers.formatCurrency(item.sellingPrice), style: const pw.TextStyle(fontSize: 11))),
                pw.Padding(padding: const pw.EdgeInsets.all(6),
                    child: pw.Text(Helpers.formatCurrency(item.total), style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11))),
              ])),
            ],
          ),
          pw.SizedBox(height: 16),

          // Totals
          pw.Align(
            alignment: pw.Alignment.centerRight,
            child: pw.SizedBox(width: 200, child: pw.Column(children: [
              _totalRow('Subtotal', Helpers.formatCurrency(subTotal)),
              if (discountAmount > 0) _totalRow('Discount', '- ${Helpers.formatCurrency(discountAmount)}'),
              if (taxAmount > 0) _totalRow('Tax', Helpers.formatCurrency(taxAmount)),
              pw.Divider(),
              _totalRow('TOTAL', Helpers.formatCurrency(grandTotal), bold: true),
              pw.SizedBox(height: 4),
              pw.Container(
                padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: pw.BoxDecoration(color: PdfColors.green100, borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4))),
                child: pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
                  pw.Text('Payment', style: const pw.TextStyle(fontSize: 11)),
                  pw.Text(paymentMethod.toUpperCase(), style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: PdfColors.green800)),
                ]),
              ),
            ])),
          ),

          pw.Spacer(),
          pw.Center(child: pw.Text('Thank you for your business!',
              style: pw.TextStyle(color: PdfColors.grey600, fontSize: 11, fontStyle: pw.FontStyle.italic))),
        ],
      ),
    ));
    return pdf.save();
  }

  static pw.Widget _totalRow(String label, String value, {bool bold = false}) =>
      pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
        pw.Text(label, style: pw.TextStyle(fontSize: 12, fontWeight: bold ? pw.FontWeight.bold : null)),
        pw.Text(value, style: pw.TextStyle(fontSize: 12, fontWeight: bold ? pw.FontWeight.bold : null,
            color: bold ? PdfColors.blue800 : null)),
      ]);

  static Future<Uint8List> generateSalesReport({
    required String shopName,
    required List<Map<String, dynamic>> sales,
    required DateTime from,
    required DateTime to,
    required double totalRevenue,
    required double totalProfit,
  }) async {
    final pdf = pw.Document();
    pdf.addPage(pw.Page(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(32),
      build: (ctx) => pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
        pw.Text(shopName, style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
        pw.Text('Sales Report: ${Helpers.formatDate(from)} - ${Helpers.formatDate(to)}',
            style: const pw.TextStyle(fontSize: 12)),
        pw.SizedBox(height: 16),
        pw.Row(children: [
          _reportStat('Total Revenue', Helpers.formatCurrency(totalRevenue)),
          pw.SizedBox(width: 20),
          _reportStat('Total Profit', Helpers.formatCurrency(totalProfit)),
          pw.SizedBox(width: 20),
          _reportStat('Total Sales', sales.length.toString()),
        ]),
        pw.SizedBox(height: 16),
        pw.Table(
          border: pw.TableBorder.all(color: PdfColors.grey300),
          children: [
            pw.TableRow(decoration: const pw.BoxDecoration(color: PdfColors.blue800),
              children: ['Invoice', 'Date', 'Customer', 'Total', 'Status'].map((h) =>
                pw.Padding(padding: const pw.EdgeInsets.all(6),
                    child: pw.Text(h, style: pw.TextStyle(color: PdfColors.white, fontWeight: pw.FontWeight.bold, fontSize: 10)))).toList()),
            ...sales.map((s) => pw.TableRow(children: [
              pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text(s['invoiceNumber'] ?? '', style: const pw.TextStyle(fontSize: 10))),
              pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text(Helpers.formatDate(DateTime.parse(s['saleDate'] ?? DateTime.now().toIso8601String())), style: const pw.TextStyle(fontSize: 10))),
              pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text(s['customerName'] ?? 'Walk-in', style: const pw.TextStyle(fontSize: 10))),
              pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text(Helpers.formatCurrency((s['grandTotal'] ?? 0).toDouble()), style: const pw.TextStyle(fontSize: 10))),
              pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text(s['paymentStatus'] ?? '', style: const pw.TextStyle(fontSize: 10))),
            ])),
          ],
        ),
      ]),
    ));
    return pdf.save();
  }

  static pw.Widget _reportStat(String label, String value) =>
      pw.Container(padding: const pw.EdgeInsets.all(10),
          decoration: pw.BoxDecoration(color: PdfColors.blue50, borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6))),
          child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
            pw.Text(label, style: const pw.TextStyle(fontSize: 10)),
            pw.Text(value, style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: PdfColors.blue800)),
          ]));
}
