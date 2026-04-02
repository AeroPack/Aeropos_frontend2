import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ezo/features/pos/layouts/base_pos_layout.dart';
import 'package:ezo/features/pos/widgets/common/product_card.dart';
import 'package:ezo/features/pos/widgets/common/totals_display.dart';
import 'package:ezo/features/pos/state/cart_state.dart';
import 'package:ezo/core/theme/app_theme.dart';
import 'package:ezo/core/database/app_database.dart';

class CompactLayout extends BasePosLayout {
  const CompactLayout({
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
    this.onSplitBill,
    this.onPrintReceipt,
    this.onOrderHold,
    this.onRecallOrder,
  });

  final VoidCallback? onSplitBill;
  final VoidCallback? onPrintReceipt;
  final VoidCallback? onOrderHold;
  final VoidCallback? onRecallOrder;

  @override
  ConsumerState<CompactLayout> createState() => _CompactLayoutState();
}

class _CompactLayoutState extends BasePosLayoutState<CompactLayout> {
  final _searchController = TextEditingController();
  final _customerSearchController = TextEditingController();
  final _notesController = TextEditingController();
  bool _showCart = true;
  bool _showNotes = false;
  bool _showBarcodeScan = false;
  bool _showCustomerSearch = false;
  String _selectedPaymentMethod = 'cash';
  final List<ProductEntity> _recentItems = [];
  final Set<int> _favoriteProductIds = {};
  bool _showFavoritesOnly = false;

  // Primary blue color scheme
  static const Color _primaryBlue = Color(0xFF1976D2);
  static const Color _primaryBlueLight = Color(0xFF42A5F5);
  static const Color _primaryBlueDark = Color(0xFF0D47A1);
  static const Color _accentBlue = Color(0xFF2196F3);

  @override
  void initState() {
    super.initState();
    _searchController.text = widget.searchQuery;
  }

  @override
  void dispose() {
    _searchController.dispose();
    _customerSearchController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          flex: _showCart ? 6 : 9,
          child: Column(
            children: [
              _buildToolbar(),
              widget.categories.when(
                data: (cats) => _buildCategoryTabs(cats),
                loading: () => const SizedBox(height: 40),
                error: (e, _) =>
                    SizedBox(height: 40, child: Center(child: Text('$e'))),
              ),
              Expanded(
                child: widget.products.when(
                  data: (products) => _buildProductGrid(products),
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (e, _) => Center(child: Text('Error: $e')),
                ),
              ),
            ],
          ),
        ),
        if (_showCart)
          Container(
            width: 380,
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.08),
                  blurRadius: 20,
                  offset: const Offset(-5, 0),
                ),
              ],
              border: Border(left: BorderSide(color: Colors.grey[200]!)),
            ),
            child: Column(
              children: [
                _buildCartHeader(),
                Expanded(
                  child: widget.cartState.items.isEmpty
                      ? _buildEmptyCart()
                      : _buildCartItems(),
                ),
                if (_showNotes) _buildNotesSection(),
                _buildQuickActionsBar(),
                PosTotalsDisplay(
                  cartState: widget.cartState,
                  onCheckout: () => widget.onCheckout(shouldSave: true),
                  compact: true,
                ),
                _buildPaymentSection(),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildToolbar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Colors.grey[100]!)),
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_ios_new, size: 20),
            onPressed: widget.onBack,
            tooltip: 'Back',
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
          const SizedBox(width: 12),
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: _primaryBlue.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.storefront, color: _primaryBlue, size: 22),
          ),
          const SizedBox(width: 12),
          // Product Search Bar
          Expanded(
            flex: 2,
            child: Container(
              height: 38,
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey[200]!),
              ),
              child: Row(
                children: [
                  const SizedBox(width: 10),
                  Icon(Icons.search, color: Colors.grey[400], size: 18),
                  const SizedBox(width: 6),
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      decoration: InputDecoration(
                        hintText: _showBarcodeScan
                            ? 'Scan or enter barcode...'
                            : 'Search products...',
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(vertical: 8),
                        isDense: true,
                        hintStyle: TextStyle(
                          color: Colors.grey[400],
                          fontSize: 13,
                        ),
                      ),
                      onChanged: widget.onSearch,
                    ),
                  ),
                  IconButton(
                    icon: Icon(
                      _showBarcodeScan ? Icons.qr_code_scanner : Icons.qr_code,
                      size: 18,
                      color: _showBarcodeScan ? _accentBlue : Colors.grey[400],
                    ),
                    onPressed: () =>
                        setState(() => _showBarcodeScan = !_showBarcodeScan),
                    tooltip: 'Scan Barcode',
                  ),
                  if (_searchController.text.isNotEmpty)
                    IconButton(
                      icon: Icon(
                        Icons.close,
                        size: 16,
                        color: Colors.grey[400],
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
          const SizedBox(width: 8),
          // Favorites Button
          _compactToolbarBtn(
            Icons.favorite_border,
            'Favorites',
            () => setState(() {
              _showFavoritesOnly = !_showFavoritesOnly;
            }),
            isActive: _showFavoritesOnly,
          ),
          const SizedBox(width: 8),
          // Customer Search Bar
          Expanded(
            flex: 2,
            child: Container(
              height: 38,
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey[200]!),
              ),
              child: Row(
                children: [
                  const SizedBox(width: 10),
                  Icon(Icons.person_search, color: Colors.grey[400], size: 18),
                  const SizedBox(width: 6),
                  Expanded(
                    child: TextField(
                      controller: _customerSearchController,
                      decoration: InputDecoration(
                        hintText: 'Search customer...',
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(vertical: 8),
                        isDense: true,
                        hintStyle: TextStyle(
                          color: Colors.grey[400],
                          fontSize: 13,
                        ),
                      ),
                      onChanged: (value) {
                        if (value.isNotEmpty) {
                          ref.read(customerSearchProvider.notifier).state =
                              value;
                        } else {
                          ref.read(customerSearchProvider.notifier).state = '';
                        }
                      },
                    ),
                  ),
                  if (_customerSearchController.text.isNotEmpty)
                    IconButton(
                      icon: Icon(
                        Icons.close,
                        size: 16,
                        color: Colors.grey[400],
                      ),
                      onPressed: () {
                        _customerSearchController.clear();
                        ref.read(customerSearchProvider.notifier).state = '';
                      },
                    ),
                  const SizedBox(width: 4),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
          _buildAddCustomerButton(),
        ],
      ),
    );
  }

  Widget _compactToolbarBtn(
    IconData icon,
    String label,
    VoidCallback onTap, {
    bool isActive = false,
  }) {
    return Tooltip(
      message: label,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: isActive
                ? _primaryBlue.withValues(alpha: 0.1)
                : Colors.transparent,
            border: Border.all(
              color: isActive ? _primaryBlue : Colors.grey[200]!,
            ),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 18,
                color: isActive ? _primaryBlue : Colors.grey[600],
              ),
              const SizedBox(width: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: isActive ? _primaryBlue : Colors.grey[600],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCategoryTabs(List<dynamic> categories) {
    return Container(
      height: 44,
      color: Colors.white,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        children: [
          _compactTabItem(
            'ALL PRODUCTS',
            widget.selectedCategoryId == null,
            () => widget.onCategoryTap(null),
          ),
          ...categories.map(
            (c) => _compactTabItem(
              c.name.toUpperCase(),
              widget.selectedCategoryId == c.id,
              () => widget.onCategoryTap(c.id),
            ),
          ),
        ],
      ),
    );
  }

  Widget _compactTabItem(String label, bool active, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        alignment: Alignment.center,
        margin: const EdgeInsets.only(right: 6),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: active ? _primaryBlue : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: active ? _primaryBlue : Colors.grey[200]!),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontWeight: FontWeight.w700,
            color: active ? Colors.white : Colors.grey[600],
            fontSize: 11,
            letterSpacing: 0.5,
          ),
        ),
      ),
    );
  }

  Widget _buildProductGrid(List<ProductEntity> products) {
    List<ProductEntity> displayProducts = products;

    if (_showFavoritesOnly) {
      displayProducts = products
          .where((p) => _favoriteProductIds.contains(p.id))
          .toList();
    }

    if (displayProducts.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              _showFavoritesOnly
                  ? Icons.favorite_border
                  : Icons.inventory_2_outlined,
              size: 48,
              color: Colors.grey[300],
            ),
            const SizedBox(height: 12),
            Text(
              _showFavoritesOnly ? 'No favorites added' : 'No products found',
              style: TextStyle(
                color: Colors.grey[500],
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              _showFavoritesOnly
                  ? 'Tap ♡ on products to add to favorites'
                  : 'Try different search or category',
              style: TextStyle(color: Colors.grey[400], fontSize: 12),
            ),
          ],
        ),
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.all(8),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 5,
        childAspectRatio: 0.85,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
      ),
      itemCount: displayProducts.length,
      itemBuilder: (_, i) => _buildCompactProductCard(displayProducts[i]),
    );
  }

  Widget _buildCompactProductCard(ProductEntity product) {
    final isFavorite = _favoriteProductIds.contains(product.id);
    final inCart = widget.cartState.items.any(
      (i) => i.product.id == product.id,
    );

    return Stack(
      children: [
        PosProductCard(
          product: product,
          onTap: () => _addToCart(product),
          size: PosCardSize.small,
          showSku: false,
        ),
        Positioned(
          top: 4,
          right: 4,
          child: GestureDetector(
            onTap: () {
              setState(() {
                if (isFavorite) {
                  _favoriteProductIds.remove(product.id);
                } else {
                  _favoriteProductIds.add(product.id);
                }
              });
            },
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 2,
                  ),
                ],
              ),
              child: Icon(
                isFavorite ? Icons.favorite : Icons.favorite_border,
                size: 14,
                color: isFavorite ? Colors.amber : Colors.grey[400],
              ),
            ),
          ),
        ),
        if (inCart)
          Positioned(
            top: 4,
            left: 4,
            child: Container(
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                color: _accentBlue,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.check, size: 10, color: Colors.white),
            ),
          ),
      ],
    );
  }

  void _addToCart(ProductEntity product) {
    widget.cartNotifier.addProduct(product);
    setState(() {
      _recentItems.removeWhere((p) => p.id == product.id);
      _recentItems.insert(0, product);
      if (_recentItems.length > 8) {
        _recentItems.removeLast();
      }
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${product.name} added to cart'),
        backgroundColor: _primaryBlue,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Widget _buildCartHeader() {
    final customer = widget.cartState.selectedCustomer;
    final itemCount = widget.cartState.items.length;
    final itemTotal = widget.cartState.total;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        border: Border(bottom: BorderSide(color: Colors.grey[200]!)),
      ),
      child: Row(
        children: [
          if (customer != null) ...[
            Icon(Icons.person, size: 16, color: _primaryBlue),
            const SizedBox(width: 4),
            Text(
              customer.name,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: _primaryBlue,
              ),
            ),
          ] else ...[
            Text(
              'CART',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w900,
                color: _primaryBlue,
              ),
            ),
          ],
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: _primaryBlue.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              '$itemCount item${itemCount != 1 ? 's' : ''}',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: _primaryBlue,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            'Rs ${itemTotal.toStringAsFixed(2)}',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: _primaryBlueDark,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCustomerSearchPanel() {
    final customer = widget.cartState.selectedCustomer;
    final customerSearch = ref.watch(customerSearchProvider);
    final customersAsync = ref.watch(posCustomerListProvider);

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Colors.grey[200]!)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (customer != null)
            Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: _primaryBlue.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: _primaryBlue.withValues(alpha: 0.2)),
              ),
              child: Row(
                children: [
                  Icon(Icons.person, size: 16, color: _primaryBlue),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      customer.name,
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                        color: _primaryBlue,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          if (customerSearch.isNotEmpty || _showCustomerSearch)
            Container(
              constraints: const BoxConstraints(maxHeight: 200),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey[200]!),
              ),
              child: customersAsync.when(
                data: (customers) {
                  final filteredCustomers = customers.where((c) {
                    final searchLower = customerSearch.toLowerCase();
                    return c.name.toLowerCase().contains(searchLower) ||
                        (c.phone?.contains(searchLower) ?? false) ||
                        (c.email?.contains(searchLower) ?? false);
                  }).toList();

                  if (filteredCustomers.isEmpty && customerSearch.isEmpty) {
                    return const Center(
                      child: Padding(
                        padding: EdgeInsets.all(16.0),
                        child: Text('Type to search customers'),
                      ),
                    );
                  }

                  return ListView(
                    shrinkWrap: true,
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    children: [
                      if (customerSearch.isNotEmpty)
                        _compactCustomerOption(
                          name: 'Create New: "$customerSearch"',
                          details: 'Add as new customer',
                          icon: Icons.person_add,
                          onTap: () {
                            widget.onShowAddCustomerDialog();
                            _customerSearchController.clear();
                            ref.read(customerSearchProvider.notifier).state =
                                '';
                            setState(() => _showCustomerSearch = false);
                          },
                        ),
                      ...filteredCustomers.map(
                        (c) => _compactCustomerOption(
                          name: c.name,
                          details: c.phone ?? c.email ?? 'No contact',
                          icon: Icons.person,
                          onTap: () {
                            widget.cartNotifier.setCustomer(c);
                            _customerSearchController.clear();
                            ref.read(customerSearchProvider.notifier).state =
                                '';
                            setState(() => _showCustomerSearch = false);
                          },
                        ),
                      ),
                    ],
                  );
                },
                loading: () => const Center(
                  child: Padding(
                    padding: EdgeInsets.all(16.0),
                    child: CircularProgressIndicator(),
                  ),
                ),
                error: (err, _) => Center(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Text(
                      'Error: $err',
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildAddCustomerButton() {
    return Tooltip(
      message: 'Add Customer',
      child: InkWell(
        onTap: () {
          widget.onShowAddCustomerDialog();
        },
        borderRadius: BorderRadius.circular(6),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: _primaryBlue.withValues(alpha: 0.1),
            border: Border.all(color: _primaryBlue.withValues(alpha: 0.3)),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.person_add_alt_1, size: 16, color: _primaryBlue),
              const SizedBox(width: 6),
              Text(
                'Add Customer',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: _primaryBlue,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _compactCustomerOption({
    required String name,
    required String details,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: _primaryBlue.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 16, color: _primaryBlue),
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
                    ),
                  ),
                  Text(
                    details,
                    style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyCart() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.shopping_cart_outlined, size: 64, color: Colors.grey[300]),
          const SizedBox(height: 12),
          Text(
            'Cart is empty',
            style: TextStyle(
              color: Colors.grey[500],
              fontWeight: FontWeight.w600,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Tap products to add them to cart',
            style: TextStyle(color: Colors.grey[400], fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildCartItems() {
    return ListView.separated(
      padding: const EdgeInsets.all(8),
      itemCount: widget.cartState.items.length,
      separatorBuilder: (context, index) => const SizedBox(height: 6),
      itemBuilder: (context, i) =>
          _compactCartItemTile(widget.cartState.items[i]),
    );
  }

  Widget _compactCartItemTile(CartItem item) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[100]!),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  item.product.name,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Text(
                'Rs ${item.total.toStringAsFixed(2)}',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 13,
                  color: _primaryBlueDark,
                ),
              ),
            ],
          ),
          if (item.product.sku != null)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                'SKU: ${item.product.sku}',
                style: TextStyle(color: Colors.grey[500], fontSize: 10),
              ),
            ),
          if (item.manualDiscount > 0)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.green.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  item.isPercentDiscount
                      ? '${item.manualDiscount.toStringAsFixed(0)}% OFF'
                      : 'Rs ${item.manualDiscount.toStringAsFixed(2)} OFF',
                  style: TextStyle(
                    color: Colors.green[700],
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          const SizedBox(height: 8),
          Row(
            children: [
              _compactQtyButton(
                Icons.remove,
                () => widget.cartNotifier.updateQuantity(
                  item.product,
                  item.quantity - 1,
                ),
              ),
              GestureDetector(
                onTap: () => _showQuantityDialog(item),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 4,
                  ),
                  child: Text(
                    '${item.quantity}',
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                    ),
                  ),
                ),
              ),
              _compactQtyButton(
                Icons.add,
                () => widget.cartNotifier.updateQuantity(
                  item.product,
                  item.quantity + 1,
                ),
              ),
              const Spacer(),
              _compactIconBtn(
                Icons.local_offer_outlined,
                'Discount',
                () => widget.onShowItemDiscount(item),
              ),
              const SizedBox(width: 4),
              _compactIconBtn(
                Icons.delete_outline,
                'Remove',
                () => widget.cartNotifier.removeProduct(item.product),
                isDestructive: true,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _compactQtyButton(IconData icon, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: _primaryBlue.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: _primaryBlue.withValues(alpha: 0.2)),
        ),
        child: Icon(icon, size: 14, color: _primaryBlue),
      ),
    );
  }

  Widget _compactIconBtn(
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
            color: isDestructive ? Colors.amber : Colors.grey[500],
          ),
        ),
      ),
    );
  }

  void _showQuantityDialog(CartItem item) {
    final controller = TextEditingController(text: '${item.quantity}');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'SET QUANTITY',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w900,
                letterSpacing: 1,
                color: _primaryBlue,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              item.product.name,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [1, 2, 3, 5, 10].map((qty) {
                return InkWell(
                  onTap: () => controller.text = qty.toString(),
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: int.tryParse(controller.text) == qty
                          ? _primaryBlue
                          : Colors.grey[100],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '$qty',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                        color: int.tryParse(controller.text) == qty
                            ? Colors.white
                            : Colors.grey[700],
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800),
              autofocus: true,
              decoration: InputDecoration(
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text(
              'CANCEL',
              style: TextStyle(fontWeight: FontWeight.w600, color: Colors.grey),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: _primaryBlue,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            onPressed: () {
              final qty = double.tryParse(controller.text) ?? 1.0;
              widget.cartNotifier.updateQuantity(item.product, qty);
              Navigator.pop(ctx);
            },
            child: const Text(
              'UPDATE',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNotesSection() {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
      child: TextField(
        controller: _notesController,
        maxLines: 2,
        decoration: InputDecoration(
          hintText:
              'Add order notes (e.g., special instructions, gift wrap)...',
          hintStyle: TextStyle(color: Colors.grey[400], fontSize: 11),
          filled: true,
          fillColor: Colors.grey[50],
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: Colors.grey[200]!),
          ),
          contentPadding: const EdgeInsets.all(10),
          isDense: true,
          prefixIcon: Icon(
            Icons.note_outlined,
            size: 16,
            color: Colors.grey[400],
          ),
        ),
        style: const TextStyle(fontSize: 12),
      ),
    );
  }

  Widget _buildQuickActionsBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        border: Border(
          top: BorderSide(color: Colors.grey[100]!),
          bottom: BorderSide(color: Colors.grey[100]!),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _compactQuickAction(Icons.receipt, 'Split Bill', widget.onSplitBill),
          _compactQuickAction(Icons.print, 'Print', widget.onPrintReceipt),
          _compactQuickAction(
            Icons.pause_circle_outline,
            'Hold',
            widget.onOrderHold,
          ),
          _compactQuickAction(Icons.history, 'Recall', widget.onRecallOrder),
          _compactQuickAction(
            Icons.note_add_outlined,
            'Notes',
            () => setState(() => _showNotes = !_showNotes),
            isActive: _showNotes,
          ),
          _compactQuickAction(
            Icons.delete_sweep_outlined,
            'Clear All',
            widget.onReset,
            isDestructive: true,
          ),
        ],
      ),
    );
  }

  Widget _compactQuickAction(
    IconData icon,
    String label,
    VoidCallback? onTap, {
    bool isDestructive = false,
    bool isActive = false,
  }) {
    return Tooltip(
      message: label,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          decoration: BoxDecoration(
            color: isActive
                ? _primaryBlue.withValues(alpha: 0.1)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 18,
                color: isDestructive
                    ? Colors.deepOrange
                    : isActive
                    ? _primaryBlue
                    : Colors.grey[600],
              ),
              const SizedBox(height: 2),
              Text(
                label,
                style: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                  color: isDestructive
                      ? Colors.deepOrange
                      : isActive
                      ? _primaryBlue
                      : Colors.grey[600],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPaymentSection() {
    final isEmpty = widget.cartState.items.isEmpty;
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
      child: Column(
        children: [
          if (!isEmpty) ...[
            Row(
              children: [
                Expanded(
                  child: _compactPaymentChip(
                    'Cash',
                    Icons.payments_outlined,
                    'cash',
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _compactPaymentChip('Card', Icons.credit_card, 'card'),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _compactPaymentChip('QR/UPI', Icons.qr_code, 'qr_upi'),
                ),
              ],
            ),
            const SizedBox(height: 10),
          ],
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              onPressed: isEmpty
                  ? null
                  : () => widget.onCheckout(
                      shouldSave: true,
                      paymentMethod: _selectedPaymentMethod,
                    ),
              style: ElevatedButton.styleFrom(
                backgroundColor: _primaryBlue,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                disabledBackgroundColor: Colors.grey[200],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(_getPaymentIcon(_selectedPaymentMethod), size: 20),
                  const SizedBox(width: 10),
                  Text(
                    isEmpty
                        ? 'Cart is empty'
                        : 'PROCEED TO PAYMENT • Rs ${widget.cartState.total.toStringAsFixed(2)}',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.5,
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
        return Icons.qr_code;
      default:
        return Icons.payment;
    }
  }

  Widget _compactPaymentChip(String label, IconData icon, String method) {
    final selected = _selectedPaymentMethod == method;
    return InkWell(
      onTap: () => setState(() => _selectedPaymentMethod = method),
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: selected ? _primaryBlue : Colors.grey[50],
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selected ? _primaryBlue : Colors.grey[200]!,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 16,
              color: selected ? Colors.white : Colors.grey[600],
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: selected ? Colors.white : Colors.grey[600],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
