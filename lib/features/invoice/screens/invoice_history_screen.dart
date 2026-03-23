import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:ezo/core/di/service_locator.dart';
import 'package:ezo/features/invoice/state/invoice_history_state.dart';
import 'package:ezo/features/invoice/screens/invoice_preview_screen.dart';
import 'package:ezo/core/database/app_database.dart';

class InvoiceHistoryScreen extends ConsumerStatefulWidget {
  const InvoiceHistoryScreen({super.key});

  @override
  ConsumerState<InvoiceHistoryScreen> createState() =>
      _InvoiceHistoryScreenState();
}

class _InvoiceHistoryScreenState extends ConsumerState<InvoiceHistoryScreen> {
  final _searchController = TextEditingController();
  DateTimeRange? _selectedDateRange;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(salesHistoryProvider.notifier).refresh();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final isDesktop = width > 900;
    final isTablet = width > 600;
    final isMobile = width <= 600;

    final state = ref.watch(salesHistoryProvider);
    final notifier = ref.read(salesHistoryProvider.notifier);
    
    // ignore: avoid_print
    print('InvoiceHistoryScreen: building with ${state.items.length} items, isLoading=${state.isLoading}');

    return Container(
      color: const Color(0xFFF8F9FF),
      child: LayoutBuilder(
        builder: (context, constraints) {
          return SingleChildScrollView(
            padding: EdgeInsets.all(isDesktop ? 32 : (isTablet ? 20 : 16)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(isMobile),
                SizedBox(height: isMobile ? 16 : 24),
                _buildSearchBar(isTablet, isMobile, notifier),
                const SizedBox(height: 20),
                _buildTableContainer(
                  state,
                  notifier,
                  isDesktop,
                  isTablet,
                  isMobile,
                ),
                const SizedBox(height: 16),
                _buildFooter(isDesktop),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildHeader(bool isMobile) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Sales History',
          style: TextStyle(
            fontSize: isMobile ? 24 : 32,
            fontWeight: FontWeight.w800,
            color: const Color(0xFF0B1C30),
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Comprehensive log of all transactions and customer interactions.',
          style: TextStyle(
            fontSize: isMobile ? 13 : 16,
            color: const Color(0xFF545F73),
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildSearchBar(
    bool isTablet,
    bool isMobile,
    SalesHistoryNotifier notifier,
  ) {
    if (isMobile) {
      return Column(
        children: [
          _buildSearchField(notifier),
          const SizedBox(height: 12),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _filterButton(
                  icon: Icons.filter_list,
                  label: 'Filters',
                  onTap: () {},
                ),
                const SizedBox(width: 8),
                _filterButton(
                  icon: Icons.calendar_today,
                  label: 'Date',
                  onTap: _showDateRangePicker,
                ),
                const SizedBox(width: 8),
                _exportButton(),
              ],
            ),
          ),
        ],
      );
    }

    return Wrap(
      spacing: 12,
      runSpacing: 12,
      alignment: WrapAlignment.start,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        SizedBox(
          width: isTablet ? 350 : 280,
          child: _buildSearchField(notifier),
        ),
        _filterButton(icon: Icons.filter_list, label: 'Filters', onTap: () {}),
        _filterButton(
          icon: Icons.calendar_today,
          label: 'Date Range',
          onTap: _showDateRangePicker,
        ),
        const SizedBox(width: 8),
        _exportButton(),
      ],
    );
  }

  Widget _buildSearchField(SalesHistoryNotifier notifier) {
    return Container(
      height: 48,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          const SizedBox(width: 12),
          const Icon(Icons.search, color: Color(0xFF717786), size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: _searchController,
              onChanged: (value) {
                _searchQuery = value.toLowerCase();
                notifier.setQuery(value);
              },
              decoration: const InputDecoration(
                hintText: 'Search by Invoice or Customer...',
                hintStyle: TextStyle(color: Color(0xFFC1C6D7), fontSize: 13),
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
          if (_searchQuery.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.close, size: 18, color: Color(0xFF717786)),
              onPressed: () {
                _searchController.clear();
                _searchQuery = '';
                notifier.setQuery('');
              },
            )
          else
            const SizedBox(width: 8),
        ],
      ),
    );
  }

  Widget _filterButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    bool isActive = false,
  }) {
    return Material(
      color: isActive ? const Color(0xFFDCE9FF) : Colors.white,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isActive
                  ? const Color(0xFF0058BC)
                  : const Color(0xFFE2E8F0),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 18,
                color: isActive
                    ? const Color(0xFF0058BC)
                    : const Color(0xFF545F73),
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: isActive
                      ? const Color(0xFF0058BC)
                      : const Color(0xFF545F73),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _exportButton() {
    return Material(
      color: const Color(0xFF0058BC),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: _exportToCsv,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF0058BC).withValues(alpha: 0.3),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.download, size: 18, color: Colors.white),
              SizedBox(width: 6),
              Text(
                'Export',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showDateRangePicker() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDateRange: _selectedDateRange,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFF0058BC),
              onPrimary: Colors.white,
              surface: Colors.white,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() => _selectedDateRange = picked);
    }
  }

  void _exportToCsv() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Exporting to CSV...'),
        backgroundColor: Color(0xFF0058BC),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Widget _buildTableContainer(
    SalesHistoryState state,
    SalesHistoryNotifier notifier,
    bool isDesktop,
    bool isTablet,
    bool isMobile,
  ) {
    if (state.isLoading) {
      return Container(
        height: 400,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Center(child: CircularProgressIndicator()),
      );
    }

    if (state.items.isEmpty) {
      return _buildEmptyState();
    }

    if (isMobile) {
      return _buildMobileList(state, notifier);
    }

    return _buildDesktopTable(state, notifier, isTablet);
  }

  Widget _buildDesktopTable(
    SalesHistoryState state,
    SalesHistoryNotifier notifier,
    bool isTablet,
  ) {
    return Container(
      constraints: const BoxConstraints(minHeight: 400),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          _buildTableHeader(isTablet),
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: state.items.length,
            separatorBuilder: (context, index) =>
                const Divider(height: 1, color: Color(0xFFE2E8F0)),
            itemBuilder: (context, index) =>
                _buildTableRow(state, index, isTablet),
          ),
          _buildPaginationFooter(state, notifier),
        ],
      ),
    );
  }

  Widget _buildTableHeader(bool isTablet) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: const BoxDecoration(
        color: Color(0xFFF1F5F9),
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: Row(
        children: [
          _headerCell('S.No', flex: 1),
          _headerCell('Invoice #', flex: 2),
          _headerCell('Date & Time', flex: 2),
          _headerCell('Product', flex: 3),
          if (isTablet) _headerCell('Customer', flex: 2),
          _headerCell('Amount', flex: 2, align: TextAlign.right),
          _headerCell('Action', flex: 1, align: TextAlign.center),
        ],
      ),
    );
  }

  Widget _headerCell(
    String text, {
    int flex = 1,
    TextAlign align = TextAlign.left,
  }) {
    return Expanded(
      flex: flex,
      child: Text(
        text.toUpperCase(),
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: Color(0xFF545F73),
          letterSpacing: 1,
        ),
        textAlign: align,
      ),
    );
  }

  Widget _buildTableRow(SalesHistoryState state, int index, bool isTablet) {
    try {
      final res = state.items[index];
      final invoice = res.readTable(ServiceLocator.instance.database.invoices);
      final item = res.readTable(ServiceLocator.instance.database.invoiceItems);
      final prod = res.readTable(ServiceLocator.instance.database.products);
      final cust = res.readTableOrNull(
        ServiceLocator.instance.database.customers,
      );
      final serialNumber = (state.page * state.limit) + index + 1;
      final customerName = cust?.name ?? 'Walk-in';
      final dateStr = DateFormat('MMM dd, yyyy').format(invoice.date);
      final timeStr = DateFormat('HH:mm').format(invoice.date);

      return Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _viewInvoice(invoice, cust, item),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Row(
              children: [
                Expanded(
                  flex: 1,
                  child: Text(
                    serialNumber.toString().padLeft(2, '0'),
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 12,
                      color: Color(0xFF717786),
                    ),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    invoice.invoiceNumber,
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                      color: Color(0xFF0B1C30),
                    ),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        dateStr,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF545F73),
                        ),
                      ),
                      Text(
                        timeStr,
                        style: const TextStyle(
                          fontSize: 11,
                          color: Color(0xFF717786),
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  flex: 3,
                  child: Row(
                    children: [
                      Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: const Color(0xFFD8E3FB),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Center(
                          child: Icon(
                            Icons.inventory_2_outlined,
                            size: 16,
                            color: Color(0xFF0058BC),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          prod.name,
                          style: const TextStyle(
                            fontWeight: FontWeight.w500,
                            fontSize: 12,
                            color: Color(0xFF0B1C30),
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
                if (isTablet)
                  Expanded(
                    flex: 2,
                    child: Row(
                      children: [
                        Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: const Color(0xFFD8E3FB),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Center(
                            child: Text(
                              customerName.isNotEmpty
                                  ? customerName[0].toUpperCase()
                                  : 'W',
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 12,
                                color: Color(0xFF0058BC),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            customerName,
                            style: const TextStyle(
                              fontWeight: FontWeight.w500,
                              fontSize: 12,
                              color: Color(0xFF0B1C30),
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                Expanded(
                  flex: 2,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        'Rs ${invoice.total.toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontFamily: 'monospace',
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                          color: Color(0xFF0058BC),
                        ),
                      ),
                      if (invoice.paymentMethod != null)
                        Container(
                          margin: const EdgeInsets.only(top: 4),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            invoice.paymentMethod!.toUpperCase(),
                            style: const TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF545F73),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                Expanded(
                  flex: 1,
                  child: Center(child: _viewPdfButton(invoice, cust, item)),
                ),
              ],
            ),
          ),
        ),
      );
    } catch (e, stack) {
      // ignore: avoid_print
      print('InvoiceHistoryScreen _buildTableRow error: $e');
      // ignore: avoid_print
      print(stack);
      return const SizedBox.shrink();
    }
  }

  Widget _viewPdfButton(
    InvoiceEntity invoice,
    CustomerEntity? customer,
    InvoiceItemEntity item,
  ) {
    return Material(
      color: const Color(0xFF0058BC).withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: () => _viewInvoice(invoice, customer, item),
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.picture_as_pdf, size: 16, color: Color(0xFF0058BC)),
              SizedBox(width: 4),
              Text(
                'VIEW',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF0058BC),
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPaginationFooter(
    SalesHistoryState state,
    SalesHistoryNotifier notifier,
  ) {
    final totalPages = (state.totalItems / state.limit).ceil();
    final currentPage = state.page + 1;
    final startItem = (state.page * state.limit) + 1;
    final endItem = (startItem + state.items.length - 1).clamp(
      0,
      state.totalItems,
    );

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: const BoxDecoration(
        color: Color(0xFFF1F5F9),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(16)),
      ),
      child: Row(
        children: [
          Text(
            'Showing $startItem - $endItem of ${state.totalItems} entries',
            style: const TextStyle(fontSize: 13, color: Color(0xFF545F73)),
          ),
          const Spacer(),
          _buildPaginationButtons(currentPage, totalPages, notifier),
        ],
      ),
    );
  }

  Widget _buildPaginationButtons(
    int currentPage,
    int totalPages,
    SalesHistoryNotifier notifier,
  ) {
    if (totalPages == 0) return const SizedBox.shrink();

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _paginationButton(
          icon: Icons.chevron_left,
          onTap: currentPage > 1
              ? () => notifier.setPage(currentPage - 2)
              : null,
        ),
        const SizedBox(width: 4),
        ...List.generate(totalPages > 5 ? 5 : totalPages, (index) {
          int pageNum;
          if (totalPages <= 5) {
            pageNum = index + 1;
          } else if (currentPage <= 3) {
            pageNum = index + 1;
          } else if (currentPage >= totalPages - 2) {
            pageNum = totalPages - 4 + index;
          } else {
            pageNum = currentPage - 2 + index;
          }
          final isActive = pageNum == currentPage;
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2),
            child: _paginationButton(
              label: pageNum.toString(),
              isActive: isActive,
              onTap: () => notifier.setPage(pageNum - 1),
            ),
          );
        }),
        const SizedBox(width: 4),
        _paginationButton(
          icon: Icons.chevron_right,
          onTap: currentPage < totalPages
              ? () => notifier.setPage(currentPage)
              : null,
        ),
      ],
    );
  }

  Widget _paginationButton({
    IconData? icon,
    String? label,
    bool isActive = false,
    VoidCallback? onTap,
  }) {
    return Material(
      color: isActive ? const Color(0xFF0058BC) : Colors.white,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isActive
                  ? const Color(0xFF0058BC)
                  : const Color(0xFFE2E8F0),
            ),
          ),
          child: Center(
            child: icon != null
                ? Icon(
                    icon,
                    size: 18,
                    color: onTap != null
                        ? const Color(0xFF0B1C30)
                        : const Color(0xFF717786),
                  )
                : Text(
                    label ?? '',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: isActive ? Colors.white : const Color(0xFF0B1C30),
                    ),
                  ),
          ),
        ),
      ),
    );
  }

  Widget _buildMobileList(
    SalesHistoryState state,
    SalesHistoryNotifier notifier,
  ) {
    return Column(
      children: [
        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: state.items.length,
          separatorBuilder: (context, index) => const SizedBox(height: 10),
          itemBuilder: (context, index) {
            try {
              final res = state.items[index];
              final invoice = res.readTable(
                ServiceLocator.instance.database.invoices,
              );
              final item = res.readTable(
                ServiceLocator.instance.database.invoiceItems,
              );
              final prod = res.readTable(
                ServiceLocator.instance.database.products,
              );
              final cust = res.readTableOrNull(
                ServiceLocator.instance.database.customers,
              );
              final customerName = cust?.name ?? 'Walk-in';

              return Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.04),
                      blurRadius: 6,
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFD8E3FB),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            invoice.invoiceNumber,
                            style: const TextStyle(
                              fontFamily: 'monospace',
                              fontWeight: FontWeight.w700,
                              fontSize: 12,
                              color: Color(0xFF0058BC),
                            ),
                          ),
                        ),
                        if (invoice.paymentMethod != null)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              invoice.paymentMethod!.toUpperCase(),
                              style: const TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF545F73),
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        const Icon(
                          Icons.inventory_2_outlined,
                          size: 14,
                          color: Color(0xFF717786),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            prod.name,
                            style: const TextStyle(
                              fontWeight: FontWeight.w500,
                              fontSize: 13,
                              color: Color(0xFF0B1C30),
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Text(
                          'Rs ${invoice.total.toStringAsFixed(2)}',
                          style: const TextStyle(
                            fontFamily: 'monospace',
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                            color: Color(0xFF0058BC),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        const Icon(
                          Icons.person_outline,
                          size: 14,
                          color: Color(0xFF717786),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            customerName,
                            style: const TextStyle(
                              fontWeight: FontWeight.w500,
                              fontSize: 12,
                              color: Color(0xFF0B1C30),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        const Icon(
                          Icons.access_time,
                          size: 14,
                          color: Color(0xFF717786),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          DateFormat('MMM dd, yyyy HH:mm').format(invoice.date),
                          style: const TextStyle(
                            fontSize: 11,
                            color: Color(0xFF545F73),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () => _viewInvoice(invoice, cust, item),
                        icon: const Icon(Icons.picture_as_pdf, size: 16),
                        label: const Text('VIEW PDF'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF0058BC),
                          side: const BorderSide(color: Color(0xFF0058BC)),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            } catch (e, stack) {
              // ignore: avoid_print
              print('InvoiceHistoryScreen mobile item error: $e');
              // ignore: avoid_print
              print(stack);
              return const SizedBox.shrink();
            }
          },
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 8,
              ),
            ],
          ),
          child: Column(
            children: [
              Text(
                'Page ${state.page + 1} of ${(state.totalItems / state.limit).ceil()}',
                style: const TextStyle(fontSize: 12, color: Color(0xFF545F73)),
              ),
              const SizedBox(height: 12),
              _buildPaginationButtons(
                state.page + 1,
                (state.totalItems / state.limit).ceil(),
                notifier,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(48),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: const BoxDecoration(
                color: Color(0xFFF1F5F9),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.receipt_long,
                size: 48,
                color: const Color(0xFF717786).withValues(alpha: 0.5),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'No sales found',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Color(0xFF0B1C30),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _searchQuery.isNotEmpty || _selectedDateRange != null
                  ? 'Try adjusting your filters'
                  : 'Complete a transaction in POS to see it here.',
              style: const TextStyle(fontSize: 13, color: Color(0xFF545F73)),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFooter(bool isDesktop) {
    if (!isDesktop) return const SizedBox.shrink();
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        const Text(
          'AeroPOS v2.4.0',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w500,
            color: Color(0xFF545F73),
            letterSpacing: 1,
          ),
        ),
        Row(
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: const BoxDecoration(
                color: Color(0xFF006B2C),
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 6),
            const Text(
              'Sync Active',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: Color(0xFF0B1C30),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Future<void> _viewInvoice(
    InvoiceEntity invoice,
    CustomerEntity? customer,
    InvoiceItemEntity item,
  ) async {
    final db = ServiceLocator.instance.database;
    final items = await db.getInvoiceItemsWithProduct(invoice.id);
    if (mounted) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => InvoicePreviewScreen(
            invoiceEntity: invoice,
            customer: customer,
            items: items,
          ),
        ),
      );
    }
  }
}
