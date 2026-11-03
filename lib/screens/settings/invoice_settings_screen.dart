// lib/screens/settings/invoice_settings_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ezinvoice/providers/invoice_provider.dart';

class InvoiceSettingsScreen extends ConsumerStatefulWidget {
  const InvoiceSettingsScreen({super.key});

  @override
  ConsumerState<InvoiceSettingsScreen> createState() => _InvoiceSettingsScreenState();
}

class _InvoiceSettingsScreenState extends ConsumerState<InvoiceSettingsScreen> {
  static const _blue = Color(0xFF1877F2);

  void _showGstSettingsDialog() {
    final cgstController = TextEditingController();
    final sgstController = TextEditingController();

    final currentCgst = ref.read(defaultCgstProvider).valueOrNull ?? 0.0;
    final currentSgst = ref.read(defaultSgstProvider).valueOrNull ?? 0.0;
    cgstController.text = currentCgst > 0 ? currentCgst.toString() : '';
    sgstController.text = currentSgst > 0 ? currentSgst.toString() : '';

    final isDark = Theme.of(context).brightness == Brightness.dark;

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.percent, color: _blue),
            SizedBox(width: 8),
            Text('Default GST Rates'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'These rates will be auto-filled when creating a new invoice.',
              style: TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 16),
            // ✅ Container gives background directly — no theme dependency
            _gstField(cgstController, 'CGST %', isDark),
            const SizedBox(height: 12),
            _gstField(sgstController, 'SGST %', isDark),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: _blue),
            onPressed: () async {
              final cgst = double.tryParse(cgstController.text.trim()) ?? 0;
              final sgst = double.tryParse(sgstController.text.trim()) ?? 0;
              await ref.read(defaultCgstProvider.notifier).setValue(cgst);
              await ref.read(defaultSgstProvider.notifier).setValue(sgst);
              if (dialogContext.mounted) Navigator.of(dialogContext).pop();
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Default GST saved: CGST ${cgst}% | SGST ${sgst}%'),
                    backgroundColor: Colors.green,
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                );
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  // ✅ Container wraps TextField directly with background color
  Widget _gstField(TextEditingController controller, String label, bool isDark) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF2A2A2A) : const Color(0xFFF0F0F0),
        borderRadius: BorderRadius.circular(12),
      ),
      child: TextField(
        controller: controller,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        decoration: InputDecoration(
          labelText: label,
          hintText: 'e.g. 9',
          prefixIcon: const Icon(Icons.percent),
          filled: true,
          fillColor: Colors.transparent,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: _blue, width: 1.5),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final currentCgst = ref.watch(defaultCgstProvider).valueOrNull ?? 0.0;
    final currentSgst = ref.watch(defaultSgstProvider).valueOrNull ?? 0.0;

    return Scaffold(
      appBar: AppBar(title: const Text('Invoice Settings')),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        children: [
          Card(
            margin: EdgeInsets.zero,
            color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: isDark ? const BorderSide(color: Color(0xFF2C2C2C), width: 1) : BorderSide.none,
            ),
            elevation: isDark ? 0 : 1,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
                  child: Text(
                    'GST SETTINGS',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: _blue, letterSpacing: 1.5),
                  ),
                ),
                ListTile(
                  leading: const Icon(Icons.percent),
                  title: const Text('Tax Rates'),
                  subtitle: Text(
                    currentCgst > 0 || currentSgst > 0
                        ? 'CGST: ${currentCgst}%  |  SGST: ${currentSgst}%'
                        : 'Not set — tap to configure',
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: _showGstSettingsDialog,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
