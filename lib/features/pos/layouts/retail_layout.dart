import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ezo/features/pos/state/cart_state.dart';
import 'package:ezo/features/pos/layouts/base_pos_layout.dart';
import 'package:ezo/features/pos/widgets/common/product_card.dart';
import 'package:ezo/features/pos/widgets/common/category_chip.dart';
import 'package:ezo/core/theme/app_theme.dart';

/// Comprehensive Retail POS Layout
/// Features: Search, Customer Mgmt, Discounts, Hold/Recall, Notes, Quick Cash,
/// Barcode indicator, Item remove, Print receipt, Loyalty points, Split payment
class RetailLayout extends BasePosLayout {
  const RetailLayout({
    super.key,
    required super.cartState,
    required super.cartNotifier,
    required super.products,
    required super.categories,
    required super.selectedCategoryId,
    required super.searchQuery,
    required super.onProductTap,
    required super.onCategoryTap,
    required super.onSearch,
    required super.onCheckout,
    required super.onOpenInvoiceSettings,
    required super.onOpenSalesHistory,
    required super.onShowAddCustomerDialog,
    required super.onShowItemDiscount,
    required super.onSetOverallDiscount,
    required super.onReset,
    required super.onBack,
  });

  @override
  ConsumerState<RetailLayout> createState() => _RetailLayoutState();
}

class _RetailLayoutState extends BasePosLayoutState<RetailLayout> {
  final _searchController = TextEditingController();
  final _notesController = TextEditingController();
  final _customerSearchController = TextEditingController();
  bool _showNotes = false;
  bool _showBarcodeScan = false;
  bool _showCustomerSearch = false;
  String _selectedPaymentMethod = 'cash';
  final List<Map<String, dynamic>> _heldOrders = [];

  @override
  void initState() {
    super.initState();
    _searchController.text = widget.searchQuery;
  }

  @override
  void dispose() {
    _searchController.dispose();
    _notesController.dispose();
    _customerSearchController.dispose();
    super.dispose();
  }

  // ─────────────────────────── BUILD ───────────────────────────

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.grey50,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Left: Product Explorer ──
          Expanded(flex: 7, child: _buildProductExplorer()),
          // ── Right: Cart / Receipt ──
          Container(
            width: 420,
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.06),
                  blurRadius: 20,
                  offset: const Offset(-4, 0),
                ),
              ],
              border: Border(left: BorderSide(color: AppColors.grey200)),
            ),
            child: _buildReceiptPanel(),
          ),
        ],
      ),
    );
  }

  // ─────────────────────── PRODUCT EXPLORER ───────────────────────

  Widget _buildProductExplorer() {
    return Column(
      children: [
        // ── Top Toolbar: Search + Barcode + Quick Filters ──
        _buildToolbar(),

        // ── Category Chips Row ──
        Container(
          height: 52,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: widget.categories.when(
            data: (cats) => ListView(
              scrollDirection: Axis.horizontal,
              children: [
                _categoryChip('All', null),
                ...cats.map((c) => _categoryChip(c.name, c.id)),
              ],
            ),
            loading: () => const SizedBox(),
            error: (e, s) => const SizedBox(),
          ),
        ),

        // ── Product Grid ──
        Expanded(
          child: widget.products.when(
            data: (products) {
              if (products.isEmpty) {
                return _emptyState(
                  Icons.inventory_2_outlined,
                  'No products found',
                  'Try a different search or category',
                );
              }
              return GridView.builder(
                padding: const EdgeInsets.all(16),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 5,
                  childAspectRatio: 0.75,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                ),
                itemCount: products.length,
                itemBuilder: (context, index) {
                  final product = products[index];
                  final inCart = widget.cartState.items.any(
                    (i) => i.product.id == product.id,
                  );
                  return _productCard(product, inCart);
                },
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('Error: $e')),
          ),
        ),
      ],
    );
  }

  // ── Toolbar ──

  Widget _buildToolbar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: AppColors.grey100)),
      ),
      child: Row(
        children: [
          // Back button
          IconButton(
            icon: const Icon(Icons.arrow_back_ios_new, size: 20),
            onPressed: widget.onBack,
            tooltip: 'Back',
          ),
          const SizedBox(width: 8),

          // Search bar
          Expanded(
            child: Container(
              height: 42,
              decoration: BoxDecoration(
                color: AppColors.grey50,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.grey200),
              ),
              child: Row(
                children: [
                  const SizedBox(width: 12),
                  Icon(Icons.search, color: AppColors.grey400, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      decoration: InputDecoration(
                        hintText: _showBarcodeScan
                            ? 'Scan or enter barcode...'
                            : 'Search products, SKU...',
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(
                          vertical: 10,
                        ),
                        isDense: true,
                        hintStyle: TextStyle(
                          color: AppColors.grey400,
                          fontSize: 14,
                        ),
                      ),
                      onChanged: widget.onSearch,
                      onSubmitted: (_) => _handleBarcodeSubmit(),
                    ),
                  ),
                  // Barcode scan toggle
                  IconButton(
                    icon: Icon(
                      _showBarcodeScan
                          ? Icons.qr_code_scanner
                          : Icons.barcode_reader,
                      size: 20,
                      color: _showBarcodeScan
                          ? AppColors.accent
                          : AppColors.grey400,
                    ),
                    onPressed: () {
                      setState(() => _showBarcodeScan = !_showBarcodeScan);
                    },
                    tooltip: 'Toggle barcode mode',
                  ),
                  if (_searchController.text.isNotEmpty)
                    IconButton(
                      icon: Icon(
                        Icons.close,
                        size: 18,
                        color: AppColors.grey400,
                      ),
                      onPressed: () {
                        _searchController.clear();
                        widget.onSearch('');
                      },
                    ),
                  const SizedBox(width: 4),
                ],
              ),
            ),
          ),
          const SizedBox(width: 12),

          // Invoice settings
          _toolbarBtn(
            Icons.settings_outlined,
            'Settings',
            widget.onOpenInvoiceSettings,
          ),
          const SizedBox(width: 8),

          // Sales history
          _toolbarBtn(
            Icons.receipt_long_outlined,
            'History',
            widget.onOpenSalesHistory,
          ),
        ],
      ),
    );
  }

  Widget _toolbarBtn(IconData icon, String tooltip, VoidCallback onTap) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            border: Border.all(color: AppColors.grey200),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 20, color: AppColors.grey600),
        ),
      ),
    );
  }

  Widget _categoryChip(String name, int? categoryId) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: PosCategoryChip(
        name: name,
        isActive: widget.selectedCategoryId == categoryId,
        onTap: () => widget.onCategoryTap(categoryId),
      ),
    );
  }

  // ── Product Card (with in-cart indicator) ──

  Widget _productCard(dynamic product, bool inCart) {
    return Stack(
      children: [
        PosProductCard(
          product: product,
          onTap: () => widget.onProductTap(product),
        ),
        if (inCart)
          Positioned(
            top: 8,
            right: 8,
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: AppColors.accent,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.check, size: 14, color: Colors.white),
            ),
          ),
      ],
    );
  }

  // ─────────────────────── RECEIPT PANEL ───────────────────────

  Widget _buildReceiptPanel() {
    return Column(
      children: [
        // Header with customer
        _buildReceiptHeader(),

        // Cart items
        Expanded(
          child: widget.cartState.items.isEmpty
              ? _emptyState(
                  Icons.shopping_cart_outlined,
                  'Cart is empty',
                  'Tap products to add them here',
                )
              : ListView.separated(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  itemCount: widget.cartState.items.length,
                  separatorBuilder: (context, index) =>
                      Divider(height: 24, color: AppColors.grey100),
                  itemBuilder: (context, index) {
                    return _cartItemTile(widget.cartState.items[index]);
                  },
                ),
        ),

        // Notes section (toggle)
        if (_showNotes) _buildNotesSection(),

        // Quick Actions
        _buildQuickActions(),

        // Totals
        _buildTotals(),

        // Payment buttons
        _buildPaymentSection(),
      ],
    );
  }

  // ── Header ──

  Widget _buildReceiptHeader() {
    final customer = widget.cartState.selectedCustomer;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Header bar
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: AppColors.text,
            border: Border(bottom: BorderSide(color: AppColors.grey700)),
          ),
          child: Row(
            children: [
              const Icon(Icons.receipt_long, color: Colors.white, size: 20),
              const SizedBox(width: 10),
              const Text(
                'ORDER',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.2,
                  fontSize: 14,
                ),
              ),
              const Spacer(),

              // Customer selector toggle
              InkWell(
                onTap: () {
                  setState(() => _showCustomerSearch = !_showCustomerSearch);
                },
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: customer != null
                        ? Colors.green.withValues(alpha: 0.2)
                        : Colors.white.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: customer != null
                          ? Colors.green.withValues(alpha: 0.3)
                          : Colors.white.withValues(alpha: 0.2),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        customer != null ? Icons.person : Icons.person_search,
                        color: Colors.white,
                        size: 16,
                      ),
                      const SizedBox(width: 6),
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 120),
                        child: Text(
                          customer?.name ?? 'Customer',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Icon(
                        _showCustomerSearch
                            ? Icons.keyboard_arrow_up
                            : Icons.keyboard_arrow_down,
                        color: Colors.white.withValues(alpha: 0.6),
                        size: 16,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),

        // Expandable customer search panel
        if (_showCustomerSearch) _buildCustomerSearchPanel(),
      ],
    );
  }

  Widget _buildCustomerSearchPanel() {
    final customer = widget.cartState.selectedCustomer;
    final customerSearch = ref.watch(customerSearchProvider);
    final customersAsync = ref.watch(posCustomerListProvider);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOut,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: AppColors.grey200)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Selected customer chip
          if (customer != null)
            Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFF0FDF4),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFBBF7D0)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: const Color(0xFF16A34A).withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.person,
                      color: Color(0xFF16A34A),
                      size: 16,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          customer.name,
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF166534),
                            fontSize: 14,
                          ),
                        ),
                        if (customer.phone != null)
                          Text(
                            customer.phone!,
                            style: TextStyle(
                              color: const Color(
                                0xFF16A34A,
                              ).withValues(alpha: 0.7),
                              fontSize: 12,
                            ),
                          ),
                      ],
                    ),
                  ),
                  InkWell(
                    onTap: () {
                      widget.cartNotifier.setCustomer(null);
                      ref.read(customerSearchProvider.notifier).state = '';
                      _customerSearchController.clear();
                    },
                    borderRadius: BorderRadius.circular(6),
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      child: const Icon(
                        Icons.close,
                        size: 18,
                        color: Color(0xFF166534),
                      ),
                    ),
                  ),
                ],
              ),
            ),

          // Search field
          Container(
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.grey50,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.grey200),
            ),
            child: Row(
              children: [
                const SizedBox(width: 10),
                Icon(Icons.search, size: 18, color: AppColors.grey400),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _customerSearchController,
                    onChanged: (val) =>
                        ref.read(customerSearchProvider.notifier).state = val,
                    style: const TextStyle(fontSize: 14),
                    decoration: InputDecoration(
                      hintText: 'Search customer by name or phone...',
                      hintStyle: TextStyle(
                        color: AppColors.grey400,
                        fontSize: 13,
                      ),
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(vertical: 10),
                      isDense: true,
                    ),
                  ),
                ),
                if (_customerSearchController.text.isNotEmpty)
                  InkWell(
                    onTap: () {
                      _customerSearchController.clear();
                      ref.read(customerSearchProvider.notifier).state = '';
                    },
                    child: Icon(
                      Icons.close,
                      size: 16,
                      color: AppColors.grey400,
                    ),
                  ),
                const SizedBox(width: 4),
                Tooltip(
                  message: 'Add New Customer',
                  child: InkWell(
                    onTap: () {
                      setState(() => _showCustomerSearch = false);
                      widget.onShowAddCustomerDialog();
                    },
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      margin: const EdgeInsets.only(right: 4),
                      decoration: BoxDecoration(
                        color: AppColors.accent.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(Icons.add, size: 18, color: AppColors.accent),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Customer search results
          if (customerSearch.isNotEmpty)
            Container(
              margin: const EdgeInsets.only(top: 8),
              constraints: const BoxConstraints(maxHeight: 180),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.grey200),
              ),
              child: customersAsync.when(
                data: (customers) {
                  return ListView(
                    shrinkWrap: true,
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    children: [
                      // Walk-in customer option
                      _customerOption(
                        name: 'Walk-in Customer',
                        phone: null,
                        icon: Icons.person_outline,
                        onTap: () {
                          widget.cartNotifier.setCustomer(null);
                          ref.read(customerSearchProvider.notifier).state = '';
                          _customerSearchController.clear();
                          setState(() => _showCustomerSearch = false);
                        },
                      ),
                      if (customers.isNotEmpty)
                        Divider(height: 1, color: AppColors.grey100),
                      if (customers.isEmpty)
                        Padding(
                          padding: const EdgeInsets.all(16),
                          child: Center(
                            child: Text(
                              'No customers found',
                              style: TextStyle(
                                color: AppColors.grey400,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        )
                      else
                        ...customers.map(
                          (c) => _customerOption(
                            name: c.name,
                            phone: c.phone,
                            icon: Icons.person,
                            onTap: () {
                              widget.cartNotifier.setCustomer(c);
                              ref.read(customerSearchProvider.notifier).state =
                                  '';
                              _customerSearchController.clear();
                              setState(() => _showCustomerSearch = false);
                            },
                          ),
                        ),
                    ],
                  );
                },
                loading: () => const Center(
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
                ),
                error: (err, _) => Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text(
                    'Error: $err',
                    style: TextStyle(color: Colors.red[400], fontSize: 12),
                  ),
                ),
              ),
            ),

          // Hint when no search
          if (customerSearch.isEmpty && customer == null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Row(
                children: [
                  Icon(Icons.info_outline, size: 14, color: AppColors.grey400),
                  const SizedBox(width: 6),
                  Text(
                    'Default: Walk-in Customer',
                    style: TextStyle(
                      fontSize: 11,
                      color: AppColors.grey400,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _customerOption({
    required String name,
    required String? phone,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.grey50,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 16, color: AppColors.grey600),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.text,
                    ),
                  ),
                  if (phone != null)
                    Text(
                      phone,
                      style: TextStyle(fontSize: 11, color: AppColors.grey400),
                    ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, size: 18, color: AppColors.grey300),
          ],
        ),
      ),
    );
  }

  // ── Cart Item Tile ──

  Widget _cartItemTile(CartItem item) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Item details
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Name + Total
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      item.product.name,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Rs ${item.total.toStringAsFixed(2)}',
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),

              // SKU
              if (item.product.sku != null)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(
                    'SKU: ${item.product.sku}',
                    style: TextStyle(color: AppColors.grey400, fontSize: 11),
                  ),
                ),

              // Discount badge
              if (item.manualDiscount > 0)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.green.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      item.isPercentDiscount
                          ? '-${item.manualDiscount.toStringAsFixed(0)}%'
                          : '-Rs ${item.manualDiscount.toStringAsFixed(2)}',
                      style: TextStyle(
                        color: Colors.green[700],
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),

              const SizedBox(height: 8),

              // Quantity controls + delete
              Row(
                children: [
                  _qtyButton(
                    Icons.remove,
                    () => widget.cartNotifier.updateQuantity(
                      item.product,
                      item.quantity - 1,
                    ),
                  ),
                  GestureDetector(
                    onTap: () => _showQuantityInputDialog(item),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 6,
                      ),
                      child: Text(
                        '${item.quantity}',
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                        ),
                      ),
                    ),
                  ),
                  _qtyButton(
                    Icons.add,
                    () => widget.cartNotifier.updateQuantity(
                      item.product,
                      item.quantity + 1,
                    ),
                  ),
                  const Spacer(),

                  // Per-item discount
                  _iconBtn(
                    Icons.local_offer_outlined,
                    'Discount',
                    () => widget.onShowItemDiscount(item),
                  ),
                  const SizedBox(width: 4),

                  // Remove item
                  _iconBtn(
                    Icons.delete_outline,
                    'Remove',
                    () => widget.cartNotifier.removeProduct(item.product),
                    isDestructive: true,
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _qtyButton(IconData icon, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: AppColors.accent.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: AppColors.accent.withValues(alpha: 0.2)),
        ),
        child: Icon(icon, size: 16, color: AppColors.accent),
      ),
    );
  }

  Widget _iconBtn(
    IconData icon,
    String tooltip,
    VoidCallback onTap, {
    bool isDestructive = false,
  }) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: Container(
          padding: const EdgeInsets.all(6),
          child: Icon(
            icon,
            size: 18,
            color: isDestructive ? Colors.red : AppColors.grey500,
          ),
        ),
      ),
    );
  }

  // ── Notes Section ──

  Widget _buildNotesSection() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.note_outlined, size: 16, color: AppColors.grey500),
              const SizedBox(width: 6),
              Text(
                'Order Notes',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.grey500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          TextField(
            controller: _notesController,
            maxLines: 2,
            decoration: InputDecoration(
              hintText: 'Add notes for this order...',
              hintStyle: TextStyle(color: AppColors.grey400, fontSize: 13),
              filled: true,
              fillColor: AppColors.grey50,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: AppColors.grey200),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: AppColors.grey200),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: AppColors.accent),
              ),
              contentPadding: const EdgeInsets.all(10),
              isDense: true,
            ),
          ),
        ],
      ),
    );
  }

  // ── Quick Actions ──

  Widget _buildQuickActions() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.grey50,
        border: Border(
          top: BorderSide(color: AppColors.grey100),
          bottom: BorderSide(color: AppColors.grey100),
        ),
      ),
      child: Row(
        children: [
          _quickAction(Icons.pause_circle_outline, 'Hold', _holdOrder),
          _quickAction(Icons.history, 'Recall', _recallOrder),
          _quickAction(Icons.note_add_outlined, 'Notes', () {
            setState(() => _showNotes = !_showNotes);
          }),
          _quickAction(Icons.print_outlined, 'Print', _printReceipt),
          _quickAction(Icons.local_offer_outlined, 'Discount', () {
            if (widget.cartState.items.isNotEmpty) {
              _showOverallDiscountDialog();
            }
          }),
          const Spacer(),
          _quickAction(
            Icons.delete_sweep_outlined,
            'Clear',
            widget.onReset,
            isDestructive: true,
          ),
        ],
      ),
    );
  }

  Widget _quickAction(
    IconData icon,
    String label,
    VoidCallback onTap, {
    bool isDestructive = false,
  }) {
    return Tooltip(
      message: label,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 20,
                color: isDestructive ? Colors.red : AppColors.grey600,
              ),
              const SizedBox(height: 2),
              Text(
                label,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: isDestructive ? Colors.red : AppColors.grey500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Totals Section ──

  Widget _buildTotals() {
    final cart = widget.cartState;
    final hasDiscount = cart.overallDiscount > 0;

    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Subtotal
          _totalLine(
            'Subtotal (${cart.items.length} items)',
            'Rs ${cart.subtotal.toStringAsFixed(2)}',
          ),

          // Item discounts
          if (cart.itemDiscounts > 0)
            _totalLine(
              'Item Discounts',
              '- Rs ${cart.itemDiscounts.toStringAsFixed(2)}',
              valueColor: Colors.green[700],
            ),

          // Overall discount
          if (hasDiscount)
            _totalLine(
              'Order Discount${cart.isOverallPercent ? ' (${cart.overallDiscount.toStringAsFixed(0)}%)' : ''}',
              '- Rs ${cart.overallDiscountAmount.toStringAsFixed(2)}',
              valueColor: Colors.green[700],
            ),

          // Tax
          _totalLine('Tax (GST)', 'Rs ${cart.taxAmount.toStringAsFixed(2)}'),

          Divider(height: 20, color: AppColors.grey200),

          // Grand total
          _totalLine(
            'TOTAL',
            'Rs ${cart.total.toStringAsFixed(2)}',
            isBold: true,
            fontSize: 20,
          ),

          // Loyalty points (if customer selected)
          if (cart.selectedCustomer != null)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Icon(Icons.stars, size: 14, color: Colors.amber[600]),
                  const SizedBox(width: 4),
                  Text(
                    'Earn ${(cart.total * 0.01).toStringAsFixed(0)} points',
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.amber[700],
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _totalLine(
    String label,
    String value, {
    bool isBold = false,
    double fontSize = 14,
    Color? valueColor,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: fontSize,
              fontWeight: isBold ? FontWeight.w800 : FontWeight.w500,
              color: AppColors.grey700,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: fontSize,
              fontWeight: FontWeight.w700,
              color: valueColor ?? AppColors.text,
            ),
          ),
        ],
      ),
    );
  }

  // ── Payment Section ──

  Widget _buildPaymentSection() {
    final isEmpty = widget.cartState.items.isEmpty;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Column(
        children: [
          // Payment method selector
          if (!isEmpty) ...[
            Text(
              'Payment Method',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: AppColors.grey400,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _paymentMethodChip(
                    'Cash',
                    Icons.payments_outlined,
                    'cash',
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _paymentMethodChip('Card', Icons.credit_card, 'card'),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _paymentMethodChip(
                    'QR / UPI',
                    Icons.qr_code_2,
                    'qr_upi',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
          ],

          // Checkout button
          SizedBox(
            width: double.infinity,
            height: 54,
            child: ElevatedButton(
              onPressed: isEmpty
                  ? null
                  : () => widget.onCheckout(
                      shouldSave: true,
                      paymentMethod: _selectedPaymentMethod,
                    ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.accent,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                disabledBackgroundColor: AppColors.grey200,
                disabledForegroundColor: AppColors.grey400,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(_getPaymentIcon(_selectedPaymentMethod), size: 22),
                  const SizedBox(width: 10),
                  Text(
                    isEmpty
                        ? 'Cart is empty'
                        : 'Pay Rs ${widget.cartState.total.toStringAsFixed(2)}',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  IconData _getPaymentIcon(String method) {
    switch (method) {
      case 'cash':
        return Icons.payments_outlined;
      case 'card':
        return Icons.credit_card;
      case 'qr_upi':
        return Icons.qr_code_2;
      default:
        return Icons.payment;
    }
  }

  Widget _paymentMethodChip(String label, IconData icon, String method) {
    final selected = _selectedPaymentMethod == method;
    return InkWell(
      onTap: () => setState(() => _selectedPaymentMethod = method),
      borderRadius: BorderRadius.circular(10),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: selected ? AppColors.accent : AppColors.grey50,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selected ? AppColors.accent : AppColors.grey200,
            width: selected ? 0 : 1,
          ),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: AppColors.accent.withValues(alpha: 0.25),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Column(
          children: [
            Icon(
              icon,
              size: 20,
              color: selected ? Colors.white : AppColors.grey500,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: selected ? Colors.white : AppColors.grey600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─────────────────────── DIALOGS / ACTIONS ───────────────────────

  void _handleBarcodeSubmit() {
    final text = _searchController.text.trim();
    if (text.isEmpty) return;
    // Search triggers via onSearch callback; barcode mode just changes hint
  }

  void _showQuantityInputDialog(CartItem item) {
    final controller = TextEditingController(text: '${item.quantity}');

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        elevation: 0,
        backgroundColor: Colors.transparent,
        child: Container(
          width: 380,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.15),
                blurRadius: 30,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Container(
                padding: const EdgeInsets.fromLTRB(24, 20, 20, 16),
                decoration: BoxDecoration(
                  color: AppColors.accent.withValues(alpha: 0.06),
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(20),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.accent.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        Icons.numbers_rounded,
                        color: AppColors.accent,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Set Quantity',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: AppColors.text,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            item.product.name,
                            style: const TextStyle(
                              fontSize: 13,
                              color: AppColors.grey500,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(ctx),
                      icon: Icon(
                        Icons.close_rounded,
                        color: AppColors.grey400,
                        size: 22,
                      ),
                      splashRadius: 20,
                    ),
                  ],
                ),
              ),

              // Body
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
                child: Column(
                  children: [
                    // Quick quantity buttons
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [1, 2, 3, 5, 10].map((qty) {
                        final selected = int.tryParse(controller.text) == qty;
                        return Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: InkWell(
                            onTap: () {
                              controller.text = qty.toString();
                              // Force rebuild via navigator context
                              (ctx as Element).markNeedsBuild();
                            },
                            borderRadius: BorderRadius.circular(10),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 18,
                                vertical: 10,
                              ),
                              decoration: BoxDecoration(
                                color: selected
                                    ? AppColors.accent
                                    : AppColors.grey50,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: selected
                                      ? AppColors.accent
                                      : AppColors.grey200,
                                ),
                              ),
                              child: Text(
                                '$qty',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  color: selected
                                      ? Colors.white
                                      : AppColors.grey700,
                                ),
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 20),

                    // Custom input
                    TextField(
                      controller: controller,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      autofocus: true,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.w800,
                        color: AppColors.text,
                      ),
                      decoration: InputDecoration(
                        hintText: '1',
                        hintStyle: TextStyle(
                          color: AppColors.grey300,
                          fontWeight: FontWeight.w800,
                        ),
                        filled: true,
                        fillColor: AppColors.grey50,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide(color: AppColors.grey200),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide(color: AppColors.grey200),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide(
                            color: AppColors.accent,
                            width: 2,
                          ),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          vertical: 18,
                        ),
                        prefixIcon: IconButton(
                          icon: Icon(
                            Icons.remove_circle_outline,
                            color: AppColors.grey400,
                          ),
                          onPressed: () {
                            final current = int.tryParse(controller.text) ?? 1;
                            if (current > 1) {
                              controller.text = (current - 1).toString();
                            }
                          },
                        ),
                        suffixIcon: IconButton(
                          icon: Icon(
                            Icons.add_circle_outline,
                            color: AppColors.accent,
                          ),
                          onPressed: () {
                            final current = int.tryParse(controller.text) ?? 0;
                            controller.text = (current + 1).toString();
                          },
                        ),
                      ),
                      onSubmitted: (value) {
                        final qty = double.tryParse(value);
                        if (qty != null && qty > 0) {
                          widget.cartNotifier.updateQuantity(item.product, qty);
                        }
                        Navigator.pop(ctx);
                      },
                    ),
                  ],
                ),
              ),

              // Footer
              Container(
                padding: const EdgeInsets.fromLTRB(24, 12, 24, 20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border(top: BorderSide(color: AppColors.grey100)),
                  borderRadius: const BorderRadius.vertical(
                    bottom: Radius.circular(20),
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(ctx),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          side: BorderSide(color: AppColors.grey200),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Text(
                          'Cancel',
                          style: TextStyle(
                            color: AppColors.grey600,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: ElevatedButton.icon(
                        onPressed: () {
                          final qty = double.tryParse(controller.text);
                          if (qty != null && qty > 0) {
                            widget.cartNotifier.updateQuantity(
                              item.product,
                              qty,
                            );
                          }
                          Navigator.pop(ctx);
                        },
                        icon: const Icon(Icons.check_circle_outline, size: 20),
                        label: const Text(
                          'Set Quantity',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.accent,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showOverallDiscountDialog() {
    final controller = TextEditingController();
    bool isPercent = true;
    final cart = widget.cartState;
    final currentTotal = cart.total;

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          final discountValue = double.tryParse(controller.text) ?? 0;
          double previewDiscount = 0;
          if (isPercent) {
            previewDiscount = currentTotal * (discountValue / 100);
          } else {
            previewDiscount = discountValue;
          }
          final discountedTotal = currentTotal - previewDiscount;

          return Dialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            elevation: 0,
            backgroundColor: Colors.transparent,
            child: Container(
              width: 420,
              constraints: const BoxConstraints(maxHeight: 580),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.15),
                    blurRadius: 30,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // ── Header ──
                  Container(
                    padding: const EdgeInsets.fromLTRB(24, 20, 20, 16),
                    decoration: BoxDecoration(
                      color: AppColors.accent.withValues(alpha: 0.06),
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(20),
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: AppColors.accent.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            Icons.local_offer_rounded,
                            color: AppColors.accent,
                            size: 22,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Order Discount',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.text,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Apply discount to entire order',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: AppColors.grey500,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.pop(ctx),
                          icon: Icon(
                            Icons.close_rounded,
                            color: AppColors.grey400,
                            size: 22,
                          ),
                          splashRadius: 20,
                        ),
                      ],
                    ),
                  ),

                  // ── Body ──
                  Flexible(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(24, 20, 24, 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Current total
                          Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: AppColors.grey50,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: AppColors.grey100),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Current Total',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: AppColors.grey600,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                Text(
                                  'Rs ${currentTotal.toStringAsFixed(2)}',
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.text,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 20),

                          // Discount type toggle
                          Text(
                            'Discount Type',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: AppColors.grey600,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Container(
                            decoration: BoxDecoration(
                              color: AppColors.grey50,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: AppColors.grey200),
                            ),
                            padding: const EdgeInsets.all(4),
                            child: Row(
                              children: [
                                Expanded(
                                  child: _discountTypeBtn(
                                    'Percentage',
                                    '%',
                                    Icons.percent_rounded,
                                    isPercent,
                                    () => setDialogState(() {
                                      isPercent = true;
                                      controller.clear();
                                    }),
                                  ),
                                ),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: _discountTypeBtn(
                                    'Fixed Amount',
                                    'Rs',
                                    Icons.currency_rupee_rounded,
                                    !isPercent,
                                    () => setDialogState(() {
                                      isPercent = false;
                                      controller.clear();
                                    }),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 20),

                          // Quick presets (only for percentage)
                          if (isPercent) ...[
                            Text(
                              'Quick Select',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: AppColors.grey600,
                              ),
                            ),
                            const SizedBox(height: 10),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [5, 10, 15, 20, 25, 50].map((p) {
                                final selected = discountValue == p.toDouble();
                                return InkWell(
                                  onTap: () {
                                    controller.text = p.toString();
                                    setDialogState(() {});
                                  },
                                  borderRadius: BorderRadius.circular(10),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 18,
                                      vertical: 10,
                                    ),
                                    decoration: BoxDecoration(
                                      color: selected
                                          ? AppColors.accent
                                          : Colors.white,
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(
                                        color: selected
                                            ? AppColors.accent
                                            : AppColors.grey200,
                                        width: selected ? 0 : 1,
                                      ),
                                    ),
                                    child: Text(
                                      '$p%',
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                        color: selected
                                            ? Colors.white
                                            : AppColors.grey700,
                                      ),
                                    ),
                                  ),
                                );
                              }).toList(),
                            ),
                            const SizedBox(height: 20),
                          ],

                          // Custom input
                          Text(
                            isPercent ? 'Custom Percentage' : 'Custom Amount',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: AppColors.grey600,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: AppColors.grey200),
                              color: Colors.white,
                            ),
                            child: Row(
                              children: [
                                // Prefix
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 14,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppColors.grey50,
                                    borderRadius: const BorderRadius.horizontal(
                                      left: Radius.circular(12),
                                    ),
                                    border: Border(
                                      right: BorderSide(
                                        color: AppColors.grey200,
                                      ),
                                    ),
                                  ),
                                  child: Text(
                                    isPercent ? '%' : 'Rs',
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.grey600,
                                    ),
                                  ),
                                ),
                                // Input
                                Expanded(
                                  child: TextField(
                                    controller: controller,
                                    keyboardType:
                                        const TextInputType.numberWithOptions(
                                          decimal: true,
                                        ),
                                    onChanged: (_) => setDialogState(() {}),
                                    style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.text,
                                    ),
                                    decoration: InputDecoration(
                                      hintText: '0',
                                      hintStyle: TextStyle(
                                        color: AppColors.grey300,
                                        fontWeight: FontWeight.w700,
                                      ),
                                      border: InputBorder.none,
                                      enabledBorder: InputBorder.none,
                                      focusedBorder: InputBorder.none,
                                      contentPadding:
                                          const EdgeInsets.symmetric(
                                            horizontal: 16,
                                            vertical: 14,
                                          ),
                                    ),
                                    autofocus: !isPercent,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 20),

                          // Preview (when discount is entered)
                          if (discountValue > 0)
                            Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: Colors.green.withValues(alpha: 0.06),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: Colors.green.withValues(alpha: 0.15),
                                ),
                              ),
                              child: Column(
                                children: [
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        'Discount Amount',
                                        style: TextStyle(
                                          fontSize: 13,
                                          color: Colors.green[700],
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                      Text(
                                        '- Rs ${previewDiscount.toStringAsFixed(2)}',
                                        style: TextStyle(
                                          fontSize: 14,
                                          color: Colors.green[700],
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Divider(
                                    color: Colors.green.withValues(alpha: 0.15),
                                    height: 1,
                                  ),
                                  const SizedBox(height: 8),
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      const Text(
                                        'New Total',
                                        style: TextStyle(
                                          fontSize: 15,
                                          fontWeight: FontWeight.w700,
                                          color: AppColors.text,
                                        ),
                                      ),
                                      Text(
                                        'Rs ${discountedTotal.toStringAsFixed(2)}',
                                        style: const TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.w800,
                                          color: AppColors.text,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),

                  // ── Footer Actions ──
                  Container(
                    padding: const EdgeInsets.fromLTRB(24, 12, 24, 20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      border: Border(top: BorderSide(color: AppColors.grey100)),
                      borderRadius: const BorderRadius.vertical(
                        bottom: Radius.circular(20),
                      ),
                    ),
                    child: Row(
                      children: [
                        // Remove discount (if exists)
                        if (cart.overallDiscount > 0)
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () {
                                widget.cartNotifier.setOverallDiscount(
                                  0,
                                  false,
                                );
                                Navigator.pop(ctx);
                              },
                              icon: Icon(
                                Icons.remove_circle_outline,
                                size: 18,
                                color: Colors.red[400],
                              ),
                              label: Text(
                                'Remove',
                                style: TextStyle(
                                  color: Colors.red[400],
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 14,
                                ),
                                side: BorderSide(
                                  color: Colors.red.withValues(alpha: 0.3),
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                            ),
                          ),
                        if (cart.overallDiscount > 0) const SizedBox(width: 12),

                        // Cancel
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => Navigator.pop(ctx),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              side: BorderSide(color: AppColors.grey200),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: Text(
                              'Cancel',
                              style: TextStyle(
                                color: AppColors.grey600,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),

                        // Apply
                        Expanded(
                          flex: 2,
                          child: ElevatedButton.icon(
                            onPressed: () {
                              final value =
                                  double.tryParse(controller.text) ?? 0;
                              widget.cartNotifier.setOverallDiscount(
                                value,
                                isPercent,
                              );
                              Navigator.pop(ctx);
                            },
                            icon: const Icon(
                              Icons.check_circle_outline,
                              size: 20,
                            ),
                            label: const Text(
                              'Apply Discount',
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 15,
                              ),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.accent,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _discountTypeBtn(
    String label,
    String icon,
    IconData iconData,
    bool selected,
    VoidCallback onTap,
  ) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: selected ? AppColors.accent : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: AppColors.accent.withValues(alpha: 0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              iconData,
              size: 18,
              color: selected ? Colors.white : AppColors.grey500,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: selected ? Colors.white : AppColors.grey600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _holdOrder() {
    if (widget.cartState.items.isEmpty) return;
    setState(() {
      _heldOrders.add({
        'items': List<CartItem>.from(widget.cartState.items),
        'customer': widget.cartState.selectedCustomer,
        'time': DateTime.now(),
      });
    });
    widget.cartNotifier.clearCart();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Order held (${_heldOrders.length} orders saved)'),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _recallOrder() {
    if (_heldOrders.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('No held orders'),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
      return;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.65,
        ),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle bar
            Container(
              margin: const EdgeInsets.only(top: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.grey300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),

            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 20, 8),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.info.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.history_rounded,
                      color: AppColors.info,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Held Orders',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            color: AppColors.text,
                          ),
                        ),
                        Text(
                          '${_heldOrders.length} order${_heldOrders.length > 1 ? 's' : ''} on hold',
                          style: const TextStyle(
                            fontSize: 13,
                            color: AppColors.grey500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(ctx),
                    icon: Icon(
                      Icons.close_rounded,
                      color: AppColors.grey400,
                      size: 22,
                    ),
                    splashRadius: 20,
                  ),
                ],
              ),
            ),
            Divider(color: AppColors.grey100, height: 1),

            // Orders list
            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                itemCount: _heldOrders.length,
                separatorBuilder: (context, index) =>
                    const SizedBox(height: 10),
                itemBuilder: (context, index) {
                  final order = _heldOrders[index];
                  final items = order['items'] as List<CartItem>;
                  final time = order['time'] as DateTime;
                  final total = items.fold(0.0, (sum, i) => sum + i.total);
                  final formattedTime =
                      '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';

                  return Dismissible(
                    key: Key('held_order_$index'),
                    direction: DismissDirection.endToStart,
                    background: Container(
                      alignment: Alignment.centerRight,
                      padding: const EdgeInsets.only(right: 20),
                      decoration: BoxDecoration(
                        color: Colors.red.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(Icons.delete_outline, color: Colors.red[400]),
                    ),
                    onDismissed: (_) {
                      setState(() => _heldOrders.removeAt(index));
                    },
                    child: InkWell(
                      onTap: () {
                        widget.cartNotifier.clearCart();
                        for (final item in items) {
                          widget.cartNotifier.addProduct(
                            item.product,
                            modifiers: item.modifiers,
                          );
                          if (item.quantity > 1) {
                            widget.cartNotifier.updateQuantity(
                              item.product,
                              item.quantity,
                            );
                          }
                        }
                        setState(() => _heldOrders.removeAt(index));
                        Navigator.pop(ctx);
                      },
                      borderRadius: BorderRadius.circular(14),
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppColors.grey50,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: AppColors.grey100),
                        ),
                        child: Row(
                          children: [
                            // Order number badge
                            Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                color: AppColors.info.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Center(
                                child: Text(
                                  '${index + 1}',
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w800,
                                    color: AppColors.info,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 14),

                            // Order details
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '${items.length} item${items.length > 1 ? 's' : ''}',
                                    style: const TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.text,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Row(
                                    children: [
                                      Icon(
                                        Icons.access_time_rounded,
                                        size: 14,
                                        color: AppColors.grey400,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        formattedTime,
                                        style: TextStyle(
                                          fontSize: 13,
                                          color: AppColors.grey500,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),

                            // Total amount
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  'Rs ${total.toStringAsFixed(2)}',
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w800,
                                    color: AppColors.text,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 3,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.orange.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    'HELD',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.orange[700],
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _printReceipt() {
    if (widget.cartState.items.isEmpty) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Printing receipt...'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  // ─────────────────────── UTILITIES ───────────────────────

  Widget _emptyState(IconData icon, String title, String subtitle) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 64, color: AppColors.grey300),
          const SizedBox(height: 16),
          Text(
            title,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: AppColors.grey500,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: TextStyle(color: AppColors.grey400, fontSize: 14),
          ),
        ],
      ),
    );
  }
}
