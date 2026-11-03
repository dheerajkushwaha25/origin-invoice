// lib/providers/dashboard_provider.dart

import 'package:flutter/material.dart' show DateTimeRange;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:collection/collection.dart';

import '../models/invoice.dart';
import '../providers/invoice_provider.dart';
import '../providers/client_provider.dart';

enum DashboardRange { thisMonth, thisQuarter, thisYear, allTime, custom }

class DashboardMetrics {
  final double totalRevenue;
  final double cgstTotal;
  final double sgstTotal;
  final double totalDiscount; // NEW: Total discount given
  final int invoicesCount;
  final double avgInvoice;
  final List<MonthlyPoint> monthly;
  final List<TopClient> topClients;

  DashboardMetrics({
    required this.totalRevenue,
    required this.cgstTotal,
    required this.sgstTotal,
    required this.totalDiscount,
    required this.invoicesCount,
    required this.avgInvoice,
    required this.monthly,
    required this.topClients,
  });
}

class MonthlyPoint {
  final DateTime month; // first day
  final double amount;
  MonthlyPoint(this.month, this.amount);
}

class TopClient {
  final String clientId;
  final String name;
  final double amount;
  TopClient({required this.clientId, required this.name, required this.amount});
}

final dashboardRangeProvider =
StateProvider<DashboardRange>((ref) => DashboardRange.thisMonth);

final dashboardCustomRangeProvider = StateProvider<DateTimeRange?>((ref) => null);

DateTime _startOfMonth(DateTime d) => DateTime(d.year, d.month, 1);
DateTime _startOfQuarter(DateTime d) {
  final qStartMonth = ((d.month - 1) ~/ 3) * 3 + 1;
  return DateTime(d.year, qStartMonth, 1);
}
DateTime _startOfYear(DateTime d) => DateTime(d.year, 1, 1);

bool _inBuiltRange(DateTime date, DashboardRange range) {
  final now = DateTime.now();
  switch (range) {
    case DashboardRange.thisMonth:
      return date.isAfter(_startOfMonth(now).subtract(const Duration(seconds: 1))) &&
          date.isBefore(DateTime(now.year, now.month + 1, 1));
    case DashboardRange.thisQuarter:
      final s = _startOfQuarter(now);
      final e = DateTime(s.year, s.month + 3, 1);
      return date.isAfter(s.subtract(const Duration(seconds: 1))) && date.isBefore(e);
    case DashboardRange.thisYear:
      final s2 = _startOfYear(now);
      final e2 = DateTime(s2.year + 1, 1, 1);
      return date.isAfter(s2.subtract(const Duration(seconds: 1))) && date.isBefore(e2);
    case DashboardRange.allTime:
      return true;
    case DashboardRange.custom:
      return true;
  }
}

bool _inCustom(DateTime date, DateTimeRange r) {
  final endInclusive = r.end.add(const Duration(days: 1));
  return date.isAfter(r.start.subtract(const Duration(seconds: 1))) && date.isBefore(endInclusive);
}

List<DateTime> _lastMonths(int n) {
  final now = DateTime.now();
  final start = DateTime(now.year, now.month, 1);
  return List.generate(n, (i) => DateTime(start.year, start.month - (n - 1 - i), 1));
}

final dashboardMetricsProvider = FutureProvider<DashboardMetrics>((ref) async {
  final invoices = await ref.watch(invoiceListProvider.future);
  final range = ref.watch(dashboardRangeProvider);
  final custom = ref.watch(dashboardCustomRangeProvider);

  // Filter
  late final List<Invoice> filtered;
  if (range == DashboardRange.custom && custom != null) {
    filtered = invoices.where((inv) => _inCustom(inv.invoiceDate, custom)).toList();
  } else {
    filtered = invoices.where((inv) => _inBuiltRange(inv.invoiceDate, range)).toList();
  }

  // Totals
  double totalRevenue = 0.0, cgst = 0.0, sgst = 0.0, totalDiscount = 0.0;
  for (final inv in filtered) {
    totalRevenue += inv.grandTotal;
    cgst += inv.cgstTotal;
    sgst += inv.sgstTotal;

    // Calculate discount: subtotal - (grandTotal - taxes)
    final taxes = inv.cgstTotal + inv.sgstTotal;
    final baseAmount = inv.grandTotal - taxes;
    final discount = inv.subtotal - baseAmount;
    totalDiscount += discount.clamp(0.0, double.infinity);
  }
  final count = filtered.length;
  final avg = count == 0 ? 0.0 : totalRevenue / count;

  // Monthly trend (last 12 months across all invoices)
  final months = _lastMonths(12);
  final monthSums = <String, double>{
    for (final m in months) '${m.year}-${m.month.toString().padLeft(2, '0')}': 0.0,
  };
  for (final inv in invoices) {
    final k = '${inv.invoiceDate.year}-${inv.invoiceDate.month.toString().padLeft(2, '0')}';
    if (monthSums.containsKey(k)) {
      monthSums[k] = (monthSums[k] ?? 0.0) + inv.grandTotal;
    }
  }
  final monthly = months
      .map((m) => MonthlyPoint(m, monthSums['${m.year}-${m.month.toString().padLeft(2, '0')}'] ?? 0.0))
      .toList();

  // Top clients (within filtered window)
  final byClient = filtered.groupListsBy((i) => i.clientId);
  final clients = await ref.watch(clientListProvider.future);
  final nameById = {for (final c in clients) c.id: c.businessName};
  final topClients = byClient.entries
      .map((e) => TopClient(
    clientId: e.key,
    name: nameById[e.key] ?? 'Unknown',
    amount: e.value.fold<double>(0.0, (s, inv) => s + inv.grandTotal),
  ))
      .toList()
    ..sort((a, b) => b.amount.compareTo(a.amount));
  final top5 = topClients.take(5).toList();

  return DashboardMetrics(
    totalRevenue: totalRevenue,
    cgstTotal: cgst,
    sgstTotal: sgst,
    totalDiscount: totalDiscount,
    invoicesCount: count,
    avgInvoice: avg,
    monthly: monthly,
    topClients: top5,
  );
});
