import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../../providers/product_provider.dart';
class AddProductScreen extends ConsumerStatefulWidget {
  final String? productId;
  const AddProductScreen({super.key, this.productId});
  @override
  ConsumerState<AddProductScreen> createState() => _AddProductScreenState();
}

class _AddProductScreenState extends ConsumerState<AddProductScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl     = TextEditingController();
  final _skuCtrl      = TextEditingController();
  final _barcodeCtrl  = TextEditingController();
  final _categoryCtrl = TextEditingController(text: 'General');
  final _buyPriceCtrl = TextEditingController();
  final _sellPriceCtrl= TextEditingController();
  final _qtyCtrl      = TextEditingController(text: '0');
  final _minStockCtrl = TextEditingController(text: '5');
  final _unitCtrl     = TextEditingController(text: 'pcs');
  bool _saving = false;

  bool get _isEditing => widget.productId != null;

  @override
  void initState() {
    super.initState();
    if (_isEditing) {
      final product = ref.read(productProvider).products
          .where((p) => p.id == widget.productId).firstOrNull;
      if (product != null) {
        _nameCtrl.text = product.name;
        _skuCtrl.text = product.sku ?? '';
        _barcodeCtrl.text = product.barcode ?? '';
        _categoryCtrl.text = product.category;
        _buyPriceCtrl.text = product.purchasePrice.toString();
        _sellPriceCtrl.text = product.sellingPrice.toString();
        _qtyCtrl.text = product.quantity.toString();
        _minStockCtrl.text = product.minStockLevel.toString();
        _unitCtrl.text = product.unit;
      }
    }
  }

  @override
  void dispose() {
    for (final c in [_nameCtrl, _skuCtrl, _barcodeCtrl, _categoryCtrl,
        _buyPriceCtrl, _sellPriceCtrl, _qtyCtrl, _minStockCtrl, _unitCtrl]) { c.dispose(); }
    super.dispose();
  }

  Future<void> _scan() async {
    final result = await showModalBottomSheet<String>(
      context: context,
      builder: (_) => SizedBox(height: 300,
        child: MobileScanner(onDetect: (capture) {
          final code = capture.barcodes.firstOrNull?.rawValue;
          if (code != null) Navigator.pop(context, code);
        })),
    );
    if (result != null) setState(() => _barcodeCtrl.text = result);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      await ref.read(productProvider.notifier).saveProduct({
        'name': _nameCtrl.text.trim(),
        'sku': _skuCtrl.text.trim(),
        'barcode': _barcodeCtrl.text.trim(),
        'category': _categoryCtrl.text.trim(),
        'purchasePrice': double.parse(_buyPriceCtrl.text),
        'sellingPrice': double.parse(_sellPriceCtrl.text),
        'quantity': int.parse(_qtyCtrl.text),
        'minStockLevel': int.parse(_minStockCtrl.text),
        'unit': _unitCtrl.text.trim(),
      }, id: widget.productId);
      if (!mounted) return;
      context.go('/products');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(_isEditing ? 'Edit Product' : 'Add Product'),
        actions: [if (_isEditing) IconButton(icon: const Icon(Icons.delete_outline_rounded, color: Colors.red),
            onPressed: () async {
              await ref.read(productProvider.notifier).deleteProduct(widget.productId!);
              if (!mounted) return;
              // ignore: use_build_context_synchronously
              context.go('/products');
            })]),
    body: Form(
      key: _formKey,
      child: ListView(padding: const EdgeInsets.all(16), children: [
        _field(_nameCtrl, 'Product Name *', validator: (v) => v == null || v.isEmpty ? 'Required' : null),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(child: _field(_skuCtrl, 'SKU')),
          const SizedBox(width: 12),
          Expanded(child: _field(_barcodeCtrl, 'Barcode',
              suffix: IconButton(icon: const Icon(Icons.qr_code_scanner_rounded), onPressed: _scan))),
        ]),
        const SizedBox(height: 12),
        _field(_categoryCtrl, 'Category'),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(child: _field(_buyPriceCtrl, 'Purchase Price *',
              type: TextInputType.number,
              validator: (v) => v == null || double.tryParse(v) == null ? 'Invalid' : null)),
          const SizedBox(width: 12),
          Expanded(child: _field(_sellPriceCtrl, 'Selling Price *',
              type: TextInputType.number,
              validator: (v) => v == null || double.tryParse(v) == null ? 'Invalid' : null)),
        ]),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(child: _field(_qtyCtrl, 'Quantity', type: TextInputType.number,
              validator: (v) => v == null || int.tryParse(v) == null ? 'Invalid' : null)),
          const SizedBox(width: 12),
          Expanded(child: _field(_minStockCtrl, 'Min Stock Alert', type: TextInputType.number)),
          const SizedBox(width: 12),
          Expanded(child: _field(_unitCtrl, 'Unit')),
        ]),
        const SizedBox(height: 24),
        ElevatedButton(
          onPressed: _saving ? null : _save,
          child: _saving ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : Text(_isEditing ? 'Update Product' : 'Add Product'),
        ),
      ]),
    ),
  );

  Widget _field(TextEditingController ctrl, String label, {
    TextInputType type = TextInputType.text,
    String? Function(String?)? validator,
    Widget? suffix,
  }) => TextFormField(
    controller: ctrl,
    decoration: InputDecoration(labelText: label, suffixIcon: suffix),
    keyboardType: type,
    validator: validator,
  );
}
