import 'package:flutter/material.dart';

class ItemDetailInputPage extends StatefulWidget {
  final Map<String, dynamic>? existingItem;

  const ItemDetailInputPage({super.key, this.existingItem});

  @override
  State<ItemDetailInputPage> createState() => _ItemDetailInputPageState();
}

class _ItemDetailInputPageState extends State<ItemDetailInputPage> {
  final _formKey = GlobalKey<FormState>();
  final _descController = TextEditingController();
  final _hsnController = TextEditingController();
  final _qtyController = TextEditingController(text: '1');
  final _rateController = TextEditingController();

  bool _isNumericMode = true;
  final FocusNode _qtyFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    if (widget.existingItem != null) {
      final item = widget.existingItem!;
      _descController.text = item['description'] ?? '';
      _hsnController.text = item['hsn_sac'] ?? '';
      _qtyController.text = (item['quantity'] ?? '1').toString();
      _rateController.text = (item['rate'] ?? 0.0).toString();
    }
  }

  @override
  void dispose() {
    _descController.dispose();
    _hsnController.dispose();
    _qtyController.dispose();
    _rateController.dispose();
    _qtyFocusNode.dispose();
    super.dispose();
  }

  int _extractNumericQty(String qtyString) {
    final numeric = qtyString.replaceAll(RegExp(r'[^\d]'), '');
    return int.tryParse(numeric) ?? 1;
  }

  void _addItem() {
    if (_formKey.currentState!.validate()) {
      final String rawQty = _qtyController.text.trim();
      final int numericQty = _extractNumericQty(rawQty);
      final Map<String, dynamic> newItem = {
        'description': _descController.text,
        'hsn_sac': _hsnController.text,
        'quantity': rawQty,
        'quantity_numeric': numericQty,
        'rate': double.tryParse(_rateController.text) ?? 0.0,
        'cgst_rate': 0.0,
        'sgst_rate': 0.0,
      };
      Navigator.pop(context, newItem);
    }
  }

  Widget _buildModeChip({required String label, required bool active, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: () {
        onTap();
        _qtyFocusNode.unfocus();
        Future.delayed(const Duration(milliseconds: 10), () {
          FocusScope.of(context).requestFocus(_qtyFocusNode);
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: active ? Colors.black : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(label, style: TextStyle(fontSize: 11, color: active ? Colors.white : Colors.black, fontWeight: FontWeight.w500)),
      ),
    );
  }

  Widget _fieldCard({required String title, required Widget child}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Card(
      color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
      elevation: isDark ? 0 : 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: isDark ? const BorderSide(color: Color(0xFF2C2C2C), width: 1) : BorderSide.none,
      ),
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.grey)),
            const SizedBox(height: 8),
            child,
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool isEditing = widget.existingItem != null;

    return Scaffold(
      appBar: AppBar(
        title: Text(isEditing ? 'Edit Item Details' : 'Add Item Details'),
        actions: [
          TextButton(
            onPressed: _addItem,
            child: const Text('DONE', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [

              // ── Item Description ─────────────────────────────────────────
              _fieldCard(
                title: 'Item Description',
                child: TextFormField(
                  controller: _descController,
                  decoration: const InputDecoration(hintText: 'Enter item description'),
                  minLines: 1,
                  maxLines: null,
                  keyboardType: TextInputType.multiline,
                  textInputAction: TextInputAction.newline,
                  validator: (v) => v!.isEmpty ? 'Description required' : null,
                ),
              ),

              // ── HSN/SAC ──────────────────────────────────────────────────
              _fieldCard(
                title: 'HSN/SAC (Optional)',
                child: TextFormField(
                  controller: _hsnController,
                  decoration: const InputDecoration(hintText: 'Enter HSN/SAC code'),
                  keyboardType: TextInputType.text,
                  textInputAction: TextInputAction.next,
                ),
              ),

              // ── Quantity ─────────────────────────────────────────────────
              _fieldCard(
                title: 'Quantity',
                child: TextFormField(
                  controller: _qtyController,
                  focusNode: _qtyFocusNode,
                  decoration: InputDecoration(
                    hintText: 'e.g. 2, 2 Set',
                    suffixIcon: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
                      padding: const EdgeInsets.all(2),
                      decoration: BoxDecoration(color: const Color(0xFFE8F0FF), borderRadius: BorderRadius.circular(20)),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _buildModeChip(label: 'ABC', active: !_isNumericMode, onTap: () => setState(() => _isNumericMode = false)),
                          const SizedBox(width: 4),
                          _buildModeChip(label: '123', active: _isNumericMode, onTap: () => setState(() => _isNumericMode = true)),
                        ],
                      ),
                    ),
                  ),
                  keyboardType: _isNumericMode ? const TextInputType.numberWithOptions(decimal: false) : TextInputType.text,
                  textInputAction: TextInputAction.next,
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'Quantity required';
                    if (!RegExp(r'\d').hasMatch(v)) return 'Quantity must contain at least one number';
                    return null;
                  },
                ),
              ),

              // ── Rate / Price ─────────────────────────────────────────────
              _fieldCard(
                title: 'Rate / Price',
                child: TextFormField(
                  controller: _rateController,
                  decoration: const InputDecoration(hintText: 'Enter rate or price', prefixText: '₹ '),
                  keyboardType: TextInputType.number,
                  textInputAction: TextInputAction.done,
                  onFieldSubmitted: (_) => _addItem(),
                  validator: (v) => v!.isEmpty ? 'Rate required' : null,
                ),
              ),

              const SizedBox(height: 16),

              // ── Button ───────────────────────────────────────────────────
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _addItem,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1877F2),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: Text(
                    isEditing ? 'Update Item' : 'Add Item',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ),

              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}
