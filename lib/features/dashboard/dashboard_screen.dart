import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart' show TypedResult;
import '../sales/state/sales_state.dart';
import '../../core/models/sale_stats.dart';
import '../../core/di/service_locator.dart';
import 'package:intl/intl.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statsAsync = ref.watch(salesStatsProvider);
    final recentSalesAsync = ref.watch(salesListStreamProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFf5f6f7),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final double width = constraints.maxWidth;
            final bool isMobile = width < 600;
            final bool isTablet = width >= 600 && width < 900;
            final double padding = isMobile ? 16.0 : 32.0;

            return statsAsync.when(
              data: (stats) => SingleChildScrollView(
                padding: EdgeInsets.all(padding),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildHeader(context, isMobile, width),
                    SizedBox(height: isMobile ? 24 : 40),
                    _buildKPIGrid(isMobile, width, stats),
                    SizedBox(height: isMobile ? 24 : 40),
                    _buildChartsRow(context, isMobile, isTablet, stats),
                    SizedBox(height: isMobile ? 24 : 40),
                    _buildTransactionsTable(isMobile, recentSalesAsync),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, stack) => Center(child: Text('Error loading stats: $err')),
            );
          },
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, bool isMobile, double width) {
    if (isMobile) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Sales Analytics',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.5,
              color: const Color(0xFF2c2f30),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Real-time performance overview across all channels.',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: const Color(0xFF595c5d),
            ),
          ),
          const SizedBox(height: 16),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildDateFilter(),
                const SizedBox(width: 8),
                _buildOutletDropdown(),
                const SizedBox(width: 8),
                _buildExportButton(),
              ],
            ),
          ),
        ],
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Flexible(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Sales Analytics',
                style: TextStyle(
                  fontSize: 36,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.5,
                  color: const Color(0xFF2c2f30),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Real-time performance overview across all channels.',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: const Color(0xFF595c5d),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 16),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildDateFilter(),
            const SizedBox(width: 12),
            _buildOutletDropdown(),
            const SizedBox(width: 12),
            _buildExportButton(),
          ],
        ),
      ],
    );
  }

  Widget _buildDateFilter() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFeff1f2),
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.all(6),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.02),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.calendar_today,
              size: 18,
              color: Color(0xFF2c2f30),
            ),
            const SizedBox(width: 8),
            const Text(
              'Last 30 Days',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Color(0xFF2c2f30),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOutletDropdown() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'All Outlets',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: Color(0xFF595c5d),
            ),
          ),
          const SizedBox(width: 4),
          const Icon(Icons.expand_more, size: 18, color: Color(0xFF595c5d)),
        ],
      ),
    );
  }

  Widget _buildExportButton() {
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF994100), Color(0xFFff7a23)],
        ),
        borderRadius: BorderRadius.circular(10),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF994100).withValues(alpha: 0.2),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {},
          borderRadius: BorderRadius.circular(10),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.ios_share, color: Color(0xFFfff0e9), size: 18),
                SizedBox(width: 8),
                Text(
                  'Export',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFFfff0e9),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildKPIGrid(bool isMobile, double availableWidth, SaleStats stats) {
    final int crossAxisCount = isMobile ? 2 : (availableWidth > 900 ? 4 : 2);
    final double spacing = isMobile ? 12 : 24;

    // Calculate card width to determine a proper aspect ratio
    final double cardWidth =
        (availableWidth - (crossAxisCount - 1) * spacing) / crossAxisCount;
    // Target card height: enough for icon row + spacer + title + value
    final double cardHeight = isMobile ? 120.0 : 140.0;
    final double aspectRatio = (cardWidth / cardHeight).clamp(0.8, 3.0);

    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: crossAxisCount,
      crossAxisSpacing: spacing,
      mainAxisSpacing: spacing,
      childAspectRatio: aspectRatio,
      children: [
        _KPIStatCard(
          icon: Icons.payments,
          iconColor: const Color(0xFF994100),
          title: 'Gross Sales',
          value: 'Rs ${stats.grossSales.toStringAsFixed(0)}',
          trend: '12%',
          trendUp: true,
          isMobile: isMobile,
        ),
        _KPIStatCard(
          icon: Icons.account_balance_wallet,
          iconColor: const Color(0xFF994100),
          title: 'Net Sales',
          value: 'Rs ${stats.netSales.toStringAsFixed(0)}',
          trend: '8.4%',
          trendUp: true,
          isMobile: isMobile,
        ),
        _KPIStatCard(
          icon: Icons.shopping_basket,
          iconColor: const Color(0xFF994100),
          title: 'Avg Order',
          value: 'Rs ${stats.avgOrder.toStringAsFixed(0)}',
          trend: '2.1%',
          trendUp: false,
          isMobile: isMobile,
        ),
        _KPIStatCard(
          icon: Icons.receipt_long,
          iconColor: const Color(0xFF994100),
          title: 'Total Orders',
          value: stats.totalOrders.toString(),
          trend: '15.7%',
          trendUp: true,
          isMobile: isMobile,
        ),
      ],
    );
  }

  Widget _buildChartsRow(BuildContext context, bool isMobile, bool isTablet, SaleStats stats) {
    if (isMobile) {
      return Column(
        children: [
          _buildRevenueChart(isMobile),
          const SizedBox(height: 16),
          _buildPaymentMethods(isMobile, stats),
        ],
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(flex: isTablet ? 1 : 2, child: _buildRevenueChart(isMobile)),
        SizedBox(width: isTablet ? 16 : 24),
        Expanded(flex: 1, child: _buildPaymentMethods(isMobile, stats)),
      ],
    );
  }

  Widget _buildRevenueChart(bool isMobile) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final double availableWidth = constraints.maxWidth;
        final double innerPadding = isMobile ? 20 : 32;
        // Chart height scales proportionally with the container width
        final double chartHeight =
            (availableWidth * 0.38).clamp(120.0, 220.0);

        return Container(
          padding: EdgeInsets.all(innerPadding),
          decoration: BoxDecoration(
            color: const Color(0xFFeff1f2),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Flexible(
                    child: Text(
                      'Revenue Trend',
                      style: TextStyle(
                        fontSize: isMobile ? 18 : 20,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF2c2f30),
                      ),
                    ),
                  ),
                  if (!isMobile)
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _buildLegendItem('Online', const Color(0xFFff7a23)),
                        const SizedBox(width: 16),
                        _buildLegendItem('In-Store', const Color(0xFF863800)),
                      ],
                    ),
                ],
              ),
              if (isMobile) ...[
                const SizedBox(height: 12),
                Row(
                  children: [
                    _buildLegendItem('Online', const Color(0xFFff7a23)),
                    const SizedBox(width: 16),
                    _buildLegendItem('In-Store', const Color(0xFF863800)),
                  ],
                ),
              ],
              SizedBox(height: isMobile ? 20 : 28),
              SizedBox(
                height: chartHeight,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    _buildBar('MON', 0.6, chartHeight, isMobile),
                    _buildBar('TUE', 0.9, chartHeight, isMobile),
                    _buildBar('WED', 0.7, chartHeight, isMobile),
                    _buildBar('THU', 0.95, chartHeight, isMobile),
                    _buildBar('FRI', 1.0, chartHeight, isMobile),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildLegendItem(String label, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: Color(0xFF595c5d),
          ),
        ),
      ],
    );
  }

  Widget _buildBar(
    String label,
    double heightFactor,
    double maxHeight,
    bool isMobile,
  ) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 3),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Container(
              height: (maxHeight - 24) * heightFactor,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [
                    const Color(0xFF994100).withValues(alpha: 0.8),
                    const Color(0xFF994100).withValues(alpha: 0.2),
                  ],
                ),
                borderRadius: BorderRadius.circular(6),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: isMobile ? 9 : 11,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF595c5d),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPaymentMethods(bool isMobile, SaleStats stats) {
    final List<({Color color, double percentage})> segments = stats.paymentMethods.map((m) {
      return (color: _getPaymentColor(m.method), percentage: m.percentage);
    }).toList();

    // If no data, show an empty placeholder segment
    if (segments.isEmpty) {
      segments.add((color: Colors.grey.withValues(alpha: 0.1), percentage: 1.0));
    }

    return Container(
      padding: EdgeInsets.all(isMobile ? 20 : 32),
      decoration: BoxDecoration(
        color: const Color(0xFFeff1f2),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Payment Methods',
            style: TextStyle(
              fontSize: isMobile ? 18 : 20,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF2c2f30),
            ),
          ),
          SizedBox(height: isMobile ? 20 : 24),
          Center(
            child: SizedBox(
              height: isMobile ? 140 : 160,
              width: isMobile ? 140 : 160,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  CustomPaint(
                    size: Size(isMobile ? 140 : 160, isMobile ? 140 : 160),
                    painter: _DonutChartPainter(
                      segments: segments,
                    ),
                  ),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        stats.totalOrders > 0 ? '100%' : '0%',
                        style: TextStyle(
                          fontSize: isMobile ? 20 : 26,
                          fontWeight: FontWeight.w900,
                          color: const Color(0xFF2c2f30),
                        ),
                      ),
                      Text(
                        'SPLIT',
                        style: TextStyle(
                          fontSize: isMobile ? 8 : 10,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1,
                          color: const Color(0xFF595c5d),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          SizedBox(height: isMobile ? 20 : 24),
          if (stats.paymentMethods.isEmpty)
            const Text('No transactions yet', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey))
          else
            ...stats.paymentMethods.map((m) => Padding(
              padding: const EdgeInsets.only(bottom: 8.0),
              child: _buildPaymentLegend(
                m.method.toUpperCase(),
                '${(m.percentage * 100).toStringAsFixed(0)}%',
                _getPaymentColor(m.method),
                isMobile,
              ),
            )),
        ],
      ),
    );
  }

  Color _getPaymentColor(String method) {
    switch (method.toLowerCase()) {
      case 'upi':
      case 'scan':
        return const Color(0xFF994100);
      case 'card':
      case 'debit card':
        return const Color(0xFFff7a23);
      case 'cash':
        return const Color(0xFF2c2f30);
      default:
        return Colors.blueGrey;
    }
  }

  Widget _buildPaymentLegend(
    String label,
    String percentage,
    Color color,
    bool isMobile,
  ) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: isMobile ? 13 : 14,
                fontWeight: FontWeight.w500,
                color: const Color(0xFF2c2f30),
              ),
            ),
          ],
        ),
        Text(
          percentage,
          style: TextStyle(
            fontSize: isMobile ? 13 : 14,
            fontWeight: FontWeight.w700,
            color: const Color(0xFF2c2f30),
          ),
        ),
      ],
    );
  }

  Widget _buildTransactionsTable(
    bool isMobile,
    AsyncValue<List<TypedResult>> salesAsync,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Padding(
            padding: EdgeInsets.all(isMobile ? 20 : 32),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Recent Transactions',
                  style: TextStyle(
                    fontSize: isMobile ? 16 : 20,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF2c2f30),
                  ),
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'View All',
                      style: TextStyle(
                        fontSize: isMobile ? 13 : 14,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF994100),
                      ),
                    ),
                    Icon(
                      Icons.chevron_right,
                      size: isMobile ? 16 : 18,
                      color: const Color(0xFF994100),
                    ),
                  ],
                ),
              ],
            ),
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              headingRowColor: WidgetStateProperty.all(
                const Color(0xFFeff1f2).withValues(alpha: 0.5),
              ),
              columnSpacing: isMobile ? 24 : 48,
              dataRowMinHeight: isMobile ? 48 : 56,
              dataRowMaxHeight: isMobile ? 52 : 60,
              columns: const [
                DataColumn(
                  label: Text(
                    'INVOICE #',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.5,
                      color: Color(0xFF595c5d),
                    ),
                  ),
                ),
                DataColumn(
                  label: Text(
                    'CUSTOMER',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.5,
                      color: Color(0xFF595c5d),
                    ),
                  ),
                ),
                DataColumn(
                  label: Text(
                    'DATE',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.5,
                      color: Color(0xFF595c5d),
                    ),
                  ),
                ),
                DataColumn(
                  label: Text(
                    'AMOUNT',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.5,
                      color: Color(0xFF595c5d),
                    ),
                  ),
                ),
                DataColumn(
                  label: Text(
                    'STATUS',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.5,
                      color: Color(0xFF595c5d),
                    ),
                  ),
                ),
              ],
              rows: salesAsync.when(
                data: (results) {
                  final db = ServiceLocator.instance.database;
                  final recent = results.take(5).toList();
                  if (recent.isEmpty) {
                    return [
                      const DataRow(
                        cells: [
                          DataCell(Text('No transactions yet')),
                          DataCell(SizedBox()),
                          DataCell(SizedBox()),
                          DataCell(SizedBox()),
                          DataCell(SizedBox()),
                        ],
                      ),
                    ];
                  }
                  return recent.map((TypedResult row) {
                    final inv = row.readTable(db.invoices);
                    final cust = row.readTableOrNull(db.customers);
                    return _buildTransactionRow(
                      inv.invoiceNumber,
                      cust?.name ?? 'Walk-in',
                      DateFormat(isMobile ? 'MMM dd' : 'MMM dd, yyyy').format(
                        inv.date,
                      ),
                      'Rs ${inv.total.toStringAsFixed(2)}',
                      'Completed',
                      true,
                      isMobile,
                    );
                  }).toList();
                },
                loading: () => [
                  const DataRow(
                    cells: [
                      DataCell(Text('Loading...')),
                      DataCell(SizedBox()),
                      DataCell(SizedBox()),
                      DataCell(SizedBox()),
                      DataCell(SizedBox()),
                    ],
                  ),
                ],
                error: (err, _) => [
                  DataRow(
                    cells: [
                      DataCell(Text('Error: $err')),
                      DataCell(const SizedBox()),
                      DataCell(const SizedBox()),
                      DataCell(const SizedBox()),
                      DataCell(const SizedBox()),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  DataRow _buildTransactionRow(
    String invoice,
    String customer,
    String date,
    String amount,
    String status,
    bool isCompleted,
    bool isMobile,
  ) {
    return DataRow(
      cells: [
        DataCell(
          Text(
            invoice,
            style: TextStyle(
              fontSize: isMobile ? 12 : 14,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF2c2f30),
            ),
          ),
        ),
        DataCell(
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: isMobile ? 26 : 30,
                height: isMobile ? 26 : 30,
                decoration: const BoxDecoration(
                  color: Color(0xFFeff1f2),
                  shape: BoxShape.circle,
                ),
              ),
              SizedBox(width: isMobile ? 8 : 10),
              Text(
                customer,
                style: TextStyle(
                  fontSize: isMobile ? 12 : 14,
                  fontWeight: FontWeight.w500,
                  color: const Color(0xFF2c2f30),
                ),
              ),
            ],
          ),
        ),
        DataCell(
          Text(
            date,
            style: TextStyle(
              fontSize: isMobile ? 12 : 14,
              color: const Color(0xFF595c5d),
            ),
          ),
        ),
        DataCell(
          Text(
            amount,
            style: TextStyle(
              fontSize: isMobile ? 12 : 14,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF2c2f30),
            ),
          ),
        ),
        DataCell(
          Container(
            padding: EdgeInsets.symmetric(
              horizontal: isMobile ? 8 : 12,
              vertical: isMobile ? 2 : 4,
            ),
            decoration: BoxDecoration(
              color: isCompleted
                  ? const Color(0xFF7ffc97).withValues(alpha: 0.1)
                  : const Color(0xFFf95630).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              status.toUpperCase(),
              style: TextStyle(
                fontSize: isMobile ? 10 : 11,
                fontWeight: FontWeight.w700,
                color: isCompleted
                    ? const Color(0xFF005f27)
                    : const Color(0xFF520c00),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _KPIStatCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String value;
  final String trend;
  final bool trendUp;
  final bool isMobile;

  const _KPIStatCard({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.value,
    required this.trend,
    required this.trendUp,
    required this.isMobile,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      padding: EdgeInsets.all(isMobile ? 14 : 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Top row: icon + trend badge
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: EdgeInsets.all(isMobile ? 6 : 8),
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  icon,
                  color: iconColor,
                  size: isMobile ? 15 : 18,
                ),
              ),
              Container(
                padding: EdgeInsets.symmetric(
                  horizontal: isMobile ? 5 : 7,
                  vertical: isMobile ? 2 : 3,
                ),
                decoration: BoxDecoration(
                  color: (trendUp
                          ? const Color(0xFF7ffc97)
                          : const Color(0xFFf95630))
                      .withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      trendUp ? Icons.trending_up : Icons.trending_down,
                      size: isMobile ? 10 : 12,
                      color: trendUp
                          ? const Color(0xFF006a2c)
                          : const Color(0xFFb02500),
                    ),
                    const SizedBox(width: 2),
                    Text(
                      trend,
                      style: TextStyle(
                        fontSize: isMobile ? 9 : 11,
                        fontWeight: FontWeight.w700,
                        color: trendUp
                            ? const Color(0xFF006a2c)
                            : const Color(0xFFb02500),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          // Bottom: title + value
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                title.toUpperCase(),
                style: TextStyle(
                  fontSize: isMobile ? 9 : 11,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.5,
                  color: const Color(0xFF595c5d),
                ),
              ),
              const SizedBox(height: 2),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  value,
                  style: TextStyle(
                    fontSize: isMobile ? 18 : 22,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF2c2f30),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DonutChartPainter extends CustomPainter {
  final List<({Color color, double percentage})> segments;

  const _DonutChartPainter({required this.segments});

  @override
  void paint(Canvas canvas, Size size) {
    final Rect rect = Rect.fromLTWH(0, 0, size.width, size.height);
    final double strokeWidth = size.width < 150 ? 12 : 16;
    double startAngle = -90 * (3.14159 / 180);

    for (final segment in segments) {
      final paint = Paint()
        ..color = segment.color
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round;

      final double sweepAngle = 2 * 3.14159 * segment.percentage;
      canvas.drawArc(rect, startAngle, sweepAngle, false, paint);
      startAngle += sweepAngle;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
