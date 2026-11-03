// lib/screens/settings/financial_dashboard_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../providers/dashboard_provider.dart';

class FinancialDashboardScreen extends ConsumerWidget {
  const FinancialDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fmt = NumberFormat.currency(locale: 'en_IN', symbol: '₹');
    final range = ref.watch(dashboardRangeProvider);
    final customRange = ref.watch(dashboardCustomRangeProvider);
    final metricsAsync = ref.watch(dashboardMetricsProvider);

    Future<void> pickCustomRange() async {
      final initial = customRange ??
          DateTimeRange(
            start: DateTime.now().subtract(const Duration(days: 30)),
            end: DateTime.now(),
          );
      final picked = await showDateRangePicker(
        context: context,
        firstDate: DateTime(2015, 1, 1),
        lastDate: DateTime.now().add(const Duration(days: 1)),
        initialDateRange: initial,
        helpText: 'Select custom date range',
        builder: (context, child) => Theme(data: Theme.of(context), child: child!),
      );
      if (picked != null) {
        ref.read(dashboardCustomRangeProvider.notifier).state = picked;
        ref.read(dashboardRangeProvider.notifier).state = DashboardRange.custom;
      }
    }

    String labelForRange(DashboardRange r) {
      switch (r) {
        case DashboardRange.thisMonth:   return 'This Month';
        case DashboardRange.thisQuarter: return 'This Quarter';
        case DashboardRange.thisYear:    return 'This Year';
        case DashboardRange.allTime:     return 'All Time';
        case DashboardRange.custom:
          if (customRange == null) return 'Custom';
          final start = DateFormat('dd MMM').format(customRange.start);
          final end = DateFormat('dd MMM').format(customRange.end);
          return 'Custom: $start – $end';
      }
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Financial Dashboard')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Wrap(
                spacing: 8,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  for (final r in [
                    DashboardRange.thisMonth,
                    DashboardRange.thisQuarter,
                    DashboardRange.thisYear,
                    DashboardRange.allTime,
                    DashboardRange.custom,
                  ])
                    ChoiceChip(
                      label: Text(labelForRange(r)),
                      selected: r == range,
                      onSelected: (_) async {
                        if (r == DashboardRange.custom) {
                          await pickCustomRange();
                        } else {
                          ref.read(dashboardRangeProvider.notifier).state = r;
                        }
                      },
                    ),
                  if (range == DashboardRange.custom)
                    OutlinedButton.icon(
                      icon: const Icon(Icons.date_range),
                      label: const Text('Change dates'),
                      onPressed: pickCustomRange,
                    ),
                ],
              ),

              const SizedBox(height: 16),

              Expanded(
                child: metricsAsync.when(
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (e, s) => Center(child: Text('Error: $e')),
                  data: (m) {
                    final totalGst = m.cgstTotal + m.sgstTotal;

                    return SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          GridView.count(
                            physics: const NeverScrollableScrollPhysics(),
                            shrinkWrap: true,
                            crossAxisCount: MediaQuery.of(context).size.width > 800 ? 4 : 2,
                            crossAxisSpacing: 12,
                            mainAxisSpacing: 12,
                            childAspectRatio: 1.8,
                            children: [
                              _StatCard(title: 'Total Revenue', value: fmt.format(m.totalRevenue), color: Colors.green),
                              _StatCard(title: 'Total GST', value: fmt.format(totalGst), color: Colors.blue),
                              _StatCard(title: 'Discount Given', value: fmt.format(m.totalDiscount), color: Colors.red),
                              _StatCard(title: 'Avg Invoice', value: fmt.format(m.avgInvoice), color: Colors.purple),
                              _StatCard(title: 'Invoices', value: '${m.invoicesCount}', color: Colors.orange),
                            ],
                          ),
                          const SizedBox(height: 24),

                          Text(
                            'Top Clients',
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(height: 8),
                          Card(
                            color: Theme.of(context).brightness == Brightness.dark ? const Color(0xFF1E1E1E) : Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                              side: Theme.of(context).brightness == Brightness.dark ? const BorderSide(color: Color(0xFF2C2C2C), width: 1) : BorderSide.none,
                            ),
                            child: m.topClients.isEmpty
                                ? const Padding(
                              padding: EdgeInsets.all(16),
                              child: Center(child: Text('No clients')),
                            )
                                : ListView.separated(
                              physics: const NeverScrollableScrollPhysics(),
                              shrinkWrap: true,
                              itemCount: m.topClients.length,
                              separatorBuilder: (_, __) => const Divider(height: 1),
                              itemBuilder: (context, i) {
                                final c = m.topClients[i];
                                return ListTile(
                                  leading: CircleAvatar(
                                    backgroundColor: const Color(0xFF1877F2),
                                    child: Text(
                                      '${i + 1}',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ),
                                  title: Text(c.name, style: const TextStyle(fontWeight: FontWeight.w500)),
                                  trailing: Text(fmt.format(c.amount),
                                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
                                );
                              },
                            ),
                          ),
                          const SizedBox(height: 24),
                        ],
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

class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  final Color color;
  const _StatCard({required this.title, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Card(
      elevation: isDark ? 0 : 2,
      color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: isDark ? const BorderSide(color: Color(0xFF2C2C2C), width: 1) : BorderSide.none),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          gradient: LinearGradient(
            colors: [
              color.withValues(alpha: 0.12),
              color.withValues(alpha: 0.06),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
            const Spacer(),
            Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color)),
          ],
        ),
      ),
    );
  }
}
