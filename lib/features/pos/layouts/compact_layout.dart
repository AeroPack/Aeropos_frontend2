import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ezo/features/pos/state/cart_state.dart';
import 'package:ezo/core/database/app_database.dart';
import 'package:ezo/core/widgets/product_image.dart';
import 'base_pos_layout.dart';

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
  });

  @override
  ConsumerState<CompactLayout> createState() => _CompactLayoutState();
}

class _CompactLayoutState extends BasePosLayoutState<CompactLayout> {
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _discountRateController = TextEditingController();
  final GlobalKey _sidebarKey = GlobalKey(debugLabel: 'billing_sidebar');
  double _sidebarWidth = 420;
  bool _isBillingOnLeft = false;
  static const double _minSidebarWidth = 320;
  static const double _maxSidebarWidthRatio = 0.6;
  static const double _dragHandleWidth = 6.0;

  @override
  void initState() {
    super.initState();
    _searchController.text = widget.searchQuery;
    _discountRateController.text = widget.cartState.overallDiscount.toString();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _discountRateController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Listen for external changes to reset discount field if needed
    ref.listen(cartProvider, (previous, next) {
      if (next.items.isEmpty &&
          (previous != null && previous.items.isNotEmpty)) {
        _discountRateController.text = "0";
      }
    });

    final width = MediaQuery.of(context).size.width;
    final isMobile = width < 900;
    final productAreaWidth = isMobile ? width : width - _sidebarWidth - _dragHandleWidth;

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      body: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (!isMobile && _isBillingOnLeft) ...[
            _billingSidebar(),
            _dragHandle(width, true),
          ],
          
          // --- PRODUCTS & CATEGORIES ---
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        "Categories",
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
                _buildCategoryList(),
                _buildProductGridHeader(width),
                Expanded(child: _buildProductGrid(productAreaWidth)),
                if (isMobile)
                  const SizedBox(height: 80), // Space for bottom bar
              ],
            ),
          ),

          if (!isMobile && !_isBillingOnLeft) ...[
            _dragHandle(width, false),
            _billingSidebar(),
          ],
        ],
      ),
      bottomNavigationBar: isMobile
          ? _buildMobileBottomBar(widget.cartState)
          : null,
    );
  }

  Widget _dragHandle(double totalWidth, bool isOnLeft) {
    return MouseRegion(
      key: ValueKey('drag_handle_${isOnLeft ? 'left' : 'right'}'),
      cursor: SystemMouseCursors.resizeColumn,
      child: GestureDetector(
        onHorizontalDragUpdate: (details) {
          setState(() {
            if (isOnLeft) {
              _sidebarWidth += details.delta.dx;
            } else {
              _sidebarWidth -= details.delta.dx;
            }
            final maxWidth = totalWidth * _maxSidebarWidthRatio;
            _sidebarWidth = _sidebarWidth.clamp(_minSidebarWidth, maxWidth);
          });
        },
        child: Container(
          width: _dragHandleWidth,
          color: Colors.transparent,
          child: Stack(
            alignment: Alignment.center,
            clipBehavior: Clip.none,
            children: [
                  // The drag line indicator
                  Container(
                    width: 2,
                    height: 60,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(1),
                    ),
                  ),
                  // The switch sides button
                  Positioned(
                    child: GestureDetector(
                      onTap: () => setState(() => _isBillingOnLeft = !_isBillingOnLeft),
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.grey.shade300),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.1),
                              blurRadius: 4,
                            ),
                          ],
                        ),
                        child: Icon(
                          Icons.swap_horiz,
                          size: 16,
                          color: Colors.grey.shade700,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
    );
  }

  Widget _billingSidebar() {
    return Container(
      key: _sidebarKey,
      width: _sidebarWidth,
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 15,
          ),
        ],
      ),
      child: _buildCartSidebar(false),
    );
  }

  // Removed _buildTopToolbar as it's now provided by PosScreen's Scaffold appBar

  Widget _buildCategoryList() {
    return widget.categories.when(
      data: (categories) => SizedBox(
        height: 100,
        child: ListView.builder(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 24),
          itemCount: categories.length + 1,
          itemBuilder: (context, index) {
            if (index == 0) {
              return _buildCategoryItem(
                name: "All",
                count: "${categories.length}",
                icon: Icons.grid_view,
                isActive: widget.selectedCategoryId == null,
                onTap: () => widget.onCategoryTap(null),
              );
            }
            final category = categories[index - 1];
            return _buildCategoryItem(
              name: category.name,
              count: "-",
              icon: Icons.category_outlined,
              isActive: widget.selectedCategoryId == category.id,
              onTap: () => widget.onCategoryTap(category.id),
            );
          },
        ),
      ),
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, stack) => Center(child: Text("Error: $err")),
    );
  }

  Widget _buildCategoryItem({
    required String name,
    required String count,
    required IconData icon,
    required bool isActive,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 100,
        margin: const EdgeInsets.only(right: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isActive ? Colors.orange : Colors.transparent,
            width: 2,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: isActive ? Colors.orange : Colors.black54),
            const SizedBox(height: 8),
            Text(
              name,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            Text(
              "$count items",
              style: const TextStyle(fontSize: 10, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProductGridHeader(double screenWidth) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 12),
      child: Wrap(
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 12,
        runSpacing: 12,
        children: [
          const Text(
            "Products",
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          SizedBox(
            width: screenWidth < 600 ? double.infinity : 200,
            height: 36,
            child: TextField(
              controller: _searchController,
              onChanged: widget.onSearch,
              decoration: InputDecoration(
                hintText: "Search",
                prefixIcon: const Icon(Icons.search, size: 18),
                contentPadding: EdgeInsets.zero,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProductGrid(double availableWidth) {
    return widget.products.when(
      data: (productList) {
        int crossAxisCount = (availableWidth / 150).floor();
        if (crossAxisCount < 2) crossAxisCount = 2; // Minimum columns

        return GridView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            childAspectRatio: 0.8,
            crossAxisSpacing: 24,
            mainAxisSpacing: 24,
          ),
          itemCount: productList.length,
          itemBuilder: (context, index) {
            final product = productList[index];
            return InkWell(
              onTap: () => widget.onProductTap(product),
              child: _productCard(product),
            );
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, _) => Center(child: Text("Error: $err")),
    );
  }

  Widget _buildCartSidebar(bool isMobile) {
    return Column(
      children: [
        _buildOrderListHeader(widget.cartState.items.length),
        _buildCustomerSearch(),
        const Divider(height: 1),
        Expanded(
          child: widget.cartState.items.isEmpty
              ? _buildEmptyCart()
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: widget.cartState.items.length,
                  separatorBuilder: (context, index) =>
                      const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final item = widget.cartState.items[index];
                    return _buildCartItem(item, widget.cartNotifier);
                  },
                ),
        ),
        _buildSummarySection(widget.cartState),
      ],
    );
  }

  Widget _buildCustomerSearch() {
    final customerSearch = ref.watch(customerSearchProvider);
    final customersAsync = ref.watch(posCustomerListProvider);

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (widget.cartState.selectedCustomer != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFF0FDF4),
                border: Border.all(color: const Color(0xFFBBF7D0)),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.person, color: Color(0xFF16A34A), size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      widget.cartState.selectedCustomer!.name,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF166534),
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () {
                      widget.cartNotifier.setCustomer(null);
                      ref.read(customerSearchProvider.notifier).state = '';
                    },
                    icon: const Icon(
                      Icons.close,
                      size: 16,
                      color: Color(0xFF166534),
                    ),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
            )
          else
            Column(
              children: [
                TextField(
                  onChanged: (val) =>
                      ref.read(customerSearchProvider.notifier).state = val,
                  decoration: InputDecoration(
                    hintText: "Search Customer...",
                    prefixIcon: const Icon(Icons.person_search, size: 18),
                    suffixIcon: IconButton(
                      icon: const Icon(
                        Icons.add_circle_outline,
                        color: Color(0xFF007AFF),
                        size: 20,
                      ),
                      onPressed: widget.onShowAddCustomerDialog,
                      tooltip: "Add New Customer",
                    ),
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 12,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: Colors.grey.shade300),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: Colors.grey.shade200),
                    ),
                  ),
                ),
                if (customerSearch.isNotEmpty)
                  Container(
                    margin: const EdgeInsets.only(top: 4),
                    constraints: const BoxConstraints(maxHeight: 200),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.1),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: customersAsync.when(
                      data: (customers) {
                        return ListView(
                          shrinkWrap: true,
                          children: [
                            ListTile(
                              leading: const Icon(
                                Icons.person_outline,
                                size: 20,
                              ),
                              title: const Text(
                                "Walk-in Customer",
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              onTap: () {
                                widget.cartNotifier.setCustomer(null);
                                ref
                                        .read(customerSearchProvider.notifier)
                                        .state =
                                    '';
                              },
                            ),
                            const Divider(height: 1),
                            if (customers.isEmpty)
                              const Padding(
                                padding: EdgeInsets.all(12.0),
                                child: Text(
                                  "No registered customers found",
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: Colors.grey,
                                  ),
                                ),
                              )
                            else
                              ...customers.map(
                                (customer) => Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    ListTile(
                                      title: Text(
                                        customer.name,
                                        style: const TextStyle(fontSize: 13),
                                      ),
                                      subtitle: customer.phone != null
                                          ? Text(
                                              customer.phone!,
                                              style: const TextStyle(
                                                fontSize: 11,
                                              ),
                                            )
                                          : null,
                                      onTap: () {
                                        widget.cartNotifier.setCustomer(
                                          customer,
                                        );
                                        ref
                                                .read(
                                                  customerSearchProvider
                                                      .notifier,
                                                )
                                                .state =
                                            '';
                                      },
                                    ),
                                    const Divider(height: 1),
                                  ],
                                ),
                              ),
                          ],
                        );
                      },
                      loading: () => const Center(
                        child: Padding(
                          padding: EdgeInsets.all(8.0),
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      ),
                      error: (err, _) => Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Text("Error: $err"),
                      ),
                    ),
                  ),
                if (customerSearch.isEmpty)
                  const Padding(
                    padding: EdgeInsets.only(top: 8.0),
                    child: Text(
                      "Default: Walk-in Customer",
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildSummarySection(CartState cartState) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Colors.grey.shade200)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Payment Summary",
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
          ),
          const SizedBox(height: 12),
          _summaryRow(
            "Sub Total",
            "Rs ${cartState.subtotal.toStringAsFixed(2)}",
          ),
          _summaryRow("GST", "Rs ${cartState.taxAmount.toStringAsFixed(2)}"),
          _summaryRow(
            "Total Discount",
            "Rs ${cartState.totalDiscount.toStringAsFixed(2)}",
            isRed: cartState.totalDiscount > 0,
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 40,
                  child: TextField(
                    controller: _discountRateController,
                    decoration: InputDecoration(
                      labelText: "Add Bill Discount",
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    keyboardType: TextInputType.number,
                    onChanged: (val) {
                      final d = double.tryParse(val) ?? 0.0;
                      widget.onSetOverallDiscount(
                        d,
                        cartState.isOverallPercent,
                      );
                    },
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                height: 40,
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _discountTypeToggle("Rs", !cartState.isOverallPercent, () {
                      widget.onSetOverallDiscount(
                        cartState.overallDiscount,
                        false,
                      );
                    }),
                    VerticalDivider(width: 1, color: Colors.grey.shade300),
                    _discountTypeToggle("%", cartState.isOverallPercent, () {
                      widget.onSetOverallDiscount(
                        cartState.overallDiscount,
                        true,
                      );
                    }),
                  ],
                ),
              ),
            ],
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Divider(),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                "Amount to be Paid",
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
              ),
              Text(
                "Rs ${cartState.total.toInt()}",
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 20,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF007AFF),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              onPressed: cartState.items.isEmpty
                  ? null
                  : () => widget.onCheckout(shouldSave: true),
              child: const Text(
                "Checkout",
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 3,
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
            childAspectRatio: 2.5,
            children: [
              _gridActionBtn(
                "Print",
                Icons.print,
                onTap: cartState.items.isEmpty
                    ? null
                    : () => widget.onCheckout(shouldSave: false),
              ),
              _gridActionBtn(
                "Invoice",
                Icons.receipt_outlined,
                onTap: cartState.items.isEmpty
                    ? null
                    : () => widget.onCheckout(shouldSave: false),
              ),
              _gridActionBtn(
                "Settings",
                Icons.settings,
                onTap: widget.onOpenInvoiceSettings,
              ),
              _gridActionBtn("Cancel", Icons.close, onTap: widget.onReset),
              _gridActionBtn("Void", Icons.bolt, onTap: null),
              _gridActionBtn(
                "Sales History",
                Icons.list_alt,
                onTap: widget.onOpenSalesHistory,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildOrderListHeader(int itemCount) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text(
            "Ordered Menus",
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                const Text(
                  "Total Menus : ",
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
                Text(
                  "$itemCount",
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCartItem(CartItem item, CartNotifier cartNotifier) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFF007AFF).withOpacity(0.2),
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: ProductImage(product: item.product, size: 50),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.product.name,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      "SKU: ${item.product.sku ?? 'N/A'}",
                      style: const TextStyle(fontSize: 10, color: Colors.grey),
                    ),
                  ],
                ),
              ),
              _qtyControl(item, cartNotifier),
              const SizedBox(width: 12),
              GestureDetector(
                onTap: () => widget.onShowItemDiscount(item),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: item.manualDiscount > 0
                          ? Colors.red.shade300
                          : Colors.grey.shade200,
                    ),
                    borderRadius: BorderRadius.circular(4),
                    color: item.manualDiscount > 0 ? Colors.red.shade50 : null,
                  ),
                  child: Text(
                    item.manualDiscount > 0
                        ? "-${item.isPercentDiscount ? '${item.manualDiscount.toInt()}%' : 'Rs ${item.manualDiscount.toInt()}'}"
                        : "Discount",
                    style: TextStyle(
                      fontSize: 11,
                      color: item.manualDiscount > 0
                          ? Colors.red
                          : Colors.black,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                onPressed: () => cartNotifier.removeProduct(item.product),
                icon: const Icon(Icons.close, size: 14, color: Colors.grey),
                constraints: const BoxConstraints(),
                padding: EdgeInsets.zero,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _itemDetailCol(
                "Item Rate",
                "Rs ${item.product.price.toStringAsFixed(2)}",
              ),
              _itemDetailCol(
                "Amount",
                "Rs ${item.subtotal.toStringAsFixed(2)}",
              ),
              _itemDetailCol(
                "Total",
                "Rs ${item.total.toStringAsFixed(2)}",
                isBold: true,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _qtyControl(CartItem item, CartNotifier cartNotifier) {
    return Row(
      children: [
        _circleBtn(
          Icons.remove,
          () => cartNotifier.updateQuantity(item.product, item.quantity - 1),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Text(
            "${item.quantity}",
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
        _circleBtn(
          Icons.add,
          () => cartNotifier.updateQuantity(item.product, item.quantity + 1),
        ),
      ],
    );
  }

  Widget _circleBtn(IconData icon, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(2),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade300),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, size: 14),
      ),
    );
  }

  Widget _buildMobileBottomBar(CartState cartState) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "${cartState.items.length} Items",
                style: const TextStyle(color: Colors.grey, fontSize: 12),
              ),
              Text(
                "Rs ${cartState.total.toInt()}",
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1E293B),
                ),
              ),
            ],
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF002140),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            onPressed: () {
              showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                backgroundColor: Colors.white,
                shape: const RoundedRectangleBorder(
                  borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                ),
                builder: (context) => DraggableScrollableSheet(
                  initialChildSize: 0.9,
                  minChildSize: 0.5,
                  maxChildSize: 0.95,
                  expand: false,
                  builder: (context, scrollController) => Column(
                    children: [
                      Container(
                        margin: const EdgeInsets.symmetric(vertical: 12),
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade300,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      Expanded(child: _buildCartSidebar(true)),
                    ],
                  ),
                ),
              );
            },
            child: const Text(
              "View Cart",
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _productCard(ProductEntity product) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade100),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Center(child: ProductImage(product: product, size: 150)),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Text(
              product.name,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: Text(
              "Rs ${product.price.toInt()}",
              style: const TextStyle(
                color: Color(0xFF00A78E),
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyCart() => const Center(
    child: Text("No products in cart", style: TextStyle(color: Colors.grey)),
  );

  Widget _summaryRow(String label, String value, {bool isRed = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              color: isRed ? Colors.red : Colors.grey.shade600,
              fontWeight: FontWeight.w500,
              fontSize: 14,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              color: isRed ? Colors.red : Colors.grey.shade600,
              fontWeight: FontWeight.w500,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _discountTypeToggle(
    String label,
    bool isSelected,
    VoidCallback onTap,
  ) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        alignment: Alignment.center,
        color: isSelected ? const Color(0xFF007AFF) : Colors.transparent,
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.black87,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            fontSize: 12,
          ),
        ),
      ),
    );
  }


  Widget _gridActionBtn(String label, IconData icon, {VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade200),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 16, color: Colors.grey.shade700),
            const SizedBox(width: 4),
            Text(
              label,
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500),
            ),
          ],
        ),
      ),
    );
  }

  Widget _itemDetailCol(String label, String value, {bool isBold = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(
            fontSize: 14,
            fontWeight: isBold ? FontWeight.bold : FontWeight.w500,
          ),
        ),
      ],
    );
  }
}
