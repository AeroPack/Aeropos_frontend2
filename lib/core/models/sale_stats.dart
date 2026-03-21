class PaymentMethodStat {
  final String method; // 'cash', 'card', 'upi', 'other'
  final double amount;
  final double percentage; // 0.0 to 1.0
  final int count;

  PaymentMethodStat({
    required this.method,
    required this.amount,
    required this.percentage,
    required this.count,
  });
}

class SaleStats {
  final double grossSales;
  final double netSales;
  final double avgOrder;
  final int totalOrders;
  final List<PaymentMethodStat> paymentMethods;

  SaleStats({
    required this.grossSales,
    required this.netSales,
    required this.avgOrder,
    required this.totalOrders,
    required this.paymentMethods,
  });

  factory SaleStats.empty() => SaleStats(
        grossSales: 0.0,
        netSales: 0.0,
        avgOrder: 0.0,
        totalOrders: 0,
        paymentMethods: [],
      );
}
