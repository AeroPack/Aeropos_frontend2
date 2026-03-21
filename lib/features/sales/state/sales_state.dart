import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart' hide Column;
import '../../../core/di/service_locator.dart';
import '../../../core/models/sale_stats.dart'; // Import the stats models

final salesListStreamProvider = StreamProvider<List<TypedResult>>((ref) {
  final database = ServiceLocator.instance.database;
  return database.watchInvoicesWithCustomer();
});

final salesStatsProvider = Provider<AsyncValue<SaleStats>>((ref) {
  final salesAsync = ref.watch(salesListStreamProvider);
  return salesAsync.whenData((results) {
    if (results.isEmpty) return SaleStats.empty();

    double gross = 0;
    int total = results.length;
    Map<String, double> methodTotals = {};
    Map<String, int> methodCounts = {};

    for (var row in results) {
      final invoice = row.readTable(ServiceLocator.instance.database.invoices);
      gross += invoice.total;
      final m = invoice.paymentMethod ?? 'other';
      methodTotals[m] = (methodTotals[m] ?? 0) + invoice.total;
      methodCounts[m] = (methodCounts[m] ?? 0) + 1;
    }

    final List<PaymentMethodStat> methods = [];
    methodTotals.forEach((method, amount) {
      methods.add(PaymentMethodStat(
        method: method,
        amount: amount,
        percentage: gross > 0 ? amount / gross : 0,
        count: methodCounts[method] ?? 0,
      ));
    });

    // Ensure common methods are always listed for consistency in reports if possible, 
    // or just let them be dynamic based on data. Let's stay dynamic for now.
    methods.sort((a, b) => b.amount.compareTo(a.amount));

    return SaleStats(
      grossSales: gross,
      netSales: gross,
      avgOrder: total > 0 ? gross / total : 0,
      totalOrders: total,
      paymentMethods: methods,
    );
  });
});
