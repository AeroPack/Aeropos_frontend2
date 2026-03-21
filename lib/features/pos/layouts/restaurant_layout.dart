import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ezo/features/pos/layouts/base_pos_layout.dart';
import 'package:ezo/features/pos/widgets/common/product_card.dart';
import 'package:ezo/features/pos/widgets/common/cart_item_tile.dart';
import 'package:ezo/features/pos/widgets/common/totals_display.dart';
import 'package:ezo/core/theme/app_theme.dart';

/// Enhanced Restaurant Layout with complete food industry features
/// Includes table management, course timing, modifiers, and kitchen integration
class RestaurantLayout extends BasePosLayout {
  const RestaurantLayout({
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
    this.onTableSelect,
    this.onCourseChange,
    this.onKitchenDisplay,
    this.onSplitBill,
    this.onPrintReceipt,
    this.onOrderHold,
    this.onRecallOrder,
  });

  final Function(String tableId)? onTableSelect;
  final Function(String courseId)? onCourseChange;
  final VoidCallback? onKitchenDisplay;
  final VoidCallback? onSplitBill;
  final VoidCallback? onPrintReceipt;
  final VoidCallback? onOrderHold;
  final VoidCallback? onRecallOrder;

  @override
  ConsumerState<RestaurantLayout> createState() => _RestaurantLayoutState();
}

class _RestaurantLayoutState extends BasePosLayoutState<RestaurantLayout> {
  int _orderType = 0;
  int _selectedCourse = 0;
  bool _showCoursePanel = false;
  final bool _isKitchenConnected = true;
  final _searchController = TextEditingController();
  final _notesController = TextEditingController();
  final _cookingInstructionsController = TextEditingController();
  String? _deliveryBoyName;

  static const _orderTypes = ['Dine In', 'Takeaway', 'Delivery'];
  static const _courses = ['Starters', 'Mains', 'Desserts', 'Beverages'];

  // Sample tables for dine-in
  final List<Map<String, dynamic>> _tables = [
    {'id': 'T01', 'name': 'Table 1', 'capacity': 4, 'status': 'occupied'},
    {'id': 'T02', 'name': 'Table 2', 'capacity': 2, 'status': 'available'},
    {'id': 'T03', 'name': 'Table 3', 'capacity': 6, 'status': 'reserved'},
    {'id': 'T04', 'name': 'Table 4', 'capacity': 4, 'status': 'available'},
    {'id': 'T05', 'name': 'Table 5', 'capacity': 2, 'status': 'occupied'},
    {'id': 'T06', 'name': 'Table 6', 'capacity': 8, 'status': 'available'},
    {'id': 'BAR1', 'name': 'Bar 1', 'capacity': 2, 'status': 'available'},
    {'id': 'BAR2', 'name': 'Bar 2', 'capacity': 2, 'status': 'occupied'},
  ];

  @override
  void initState() {
    super.initState();
    _searchController.text = widget.searchQuery;
  }

  @override
  void dispose() {
    _searchController.dispose();
    _notesController.dispose();
    _cookingInstructionsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        // Left Panel - Products with Enhanced Features
        Expanded(
          flex: 7,
          child: Column(
            children: [
              // Enhanced Toolbar with Course Selection
              _buildEnhancedToolbar(),

              // Kitchen Status Indicator
              if (_orderType == 0) _buildKitchenStatus(),

              // Course Selection Panel (for fine dining)
              if (_showCoursePanel) _buildCoursePanel(),

              // Category Tabs
              widget.categories.when(
                data: (cats) => _buildCategoryTabs(cats),
                loading: () => const SizedBox(height: 48),
                error: (e, _) =>
                    SizedBox(height: 48, child: Center(child: Text('$e'))),
              ),

              // Product Grid with Modifiers Support
              Expanded(
                child: widget.products.when(
                  data: (products) => GridView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 5,
                          childAspectRatio: 0.75,
                          crossAxisSpacing: 10,
                          mainAxisSpacing: 10,
                        ),
                    itemCount: products.length,
                    itemBuilder: (_, i) =>
                        _buildProductCardWithModifiers(products[i]),
                  ),
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (e, _) => Center(child: Text('Error: $e')),
                ),
              ),
            ],
          ),
        ),

        // Right Panel - Enhanced Cart with Restaurant Features
        Container(
          width: 420,
          decoration: BoxDecoration(
            color: AppColors.surface,
            boxShadow: [
              BoxShadow(
                color: AppColors.text.withValues(alpha: 0.08),
                blurRadius: 20,
                offset: const Offset(-5, 0),
              ),
            ],
            border: Border(left: BorderSide(color: AppColors.grey200)),
          ),
          child: Column(
            children: [
              // Customer & Table Management
              _buildCustomerTableSection(),

              // Order Type Badge with Course Info
              _buildOrderTypeBadge(),

              // Course-based Cart Items
              Expanded(
                child: widget.cartState.items.isEmpty
                    ? _buildEmptyCart()
                    : _buildCourseBasedCartItems(),
              ),

              // Order Notes & Special Instructions
              _buildOrderInstructions(),

              // Quick Actions Bar
              _buildQuickActionsBar(),

              // Totals Display
              PosTotalsDisplay(
                cartState: widget.cartState,
                onCheckout: () => widget.onCheckout(shouldSave: true),
              ),

              // Order Type Selection (Above Checkout Logic)
              _buildOrderTypeSelector(),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildEnhancedToolbar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border(bottom: BorderSide(color: AppColors.grey100)),
      ),
      child: Row(
        children: [
          // Course Toggle
          IconButton(
            onPressed: () =>
                setState(() => _showCoursePanel = !_showCoursePanel),
            icon: Icon(
              _showCoursePanel ? Icons.layers_outlined : Icons.restaurant_menu,
              color: AppColors.primary,
            ),
            tooltip: 'Course Management',
          ),
          const SizedBox(width: 8),

          // Course Toggle (for dine-in)
          if (_orderType == 0)
            Container(
              margin: const EdgeInsets.only(left: 12),
              child: IconButton(
                onPressed: () =>
                    setState(() => _showCoursePanel = !_showCoursePanel),
                icon: Icon(
                  _showCoursePanel ? Icons.layers_outlined : Icons.restaurant_menu,
                  color: AppColors.primary,
                ),
                tooltip: 'Course Management',
              ),
            ),

          // Search Bar
          Expanded(
            flex: 3,
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 12),
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'Search menu items...',
                  prefixIcon: const Icon(Icons.search, size: 20),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: Colors.grey.shade300),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  isDense: true,
                ),
                onChanged: widget.onSearch,
              ),
            ),
          ),

          // Kitchen Display Button
          if (_orderType == 0)
            Container(
              margin: const EdgeInsets.only(left: AppSpacing.sm),
              decoration: BoxDecoration(
                color: (_isKitchenConnected ? Colors.green : Colors.orange).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: IconButton(
                onPressed: widget.onKitchenDisplay,
                icon: const Icon(Icons.kitchen_outlined),
                tooltip: 'Kitchen Display',
                color: _isKitchenConnected ? Colors.green : Colors.orange,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildKitchenStatus() {
    return Container(
      height: 32,
      color: _isKitchenConnected ? Colors.green.shade50 : Colors.orange.shade50,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            _isKitchenConnected ? Icons.check_circle : Icons.warning,
            size: 14,
            color: _isKitchenConnected ? Colors.green : Colors.orange,
          ),
          const SizedBox(width: AppSpacing.sm),
          Text(
            _isKitchenConnected
                ? 'Kitchen System Online'
                : 'Kitchen System Disconnected',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.5,
              color: _isKitchenConnected ? Colors.green.shade700 : Colors.orange.shade700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCoursePanel() {
    return Container(
      height: 48,
      color: Colors.grey.shade50,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        itemCount: _courses.length,
        itemBuilder: (context, index) {
          final isSelected = _selectedCourse == index;
          return GestureDetector(
            onTap: () => setState(() => _selectedCourse = index),
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: isSelected ? AppColors.accent : AppColors.surface,
                borderRadius: BorderRadius.circular(8),
                boxShadow: isSelected ? AppShadows.md : null,
                border: Border.all(
                  color: isSelected
                      ? AppColors.accent
                      : AppColors.grey200,
                ),
              ),
              child: Center(
                child: Text(
                  _courses[index].toUpperCase(),
                  style: TextStyle(
                    color: isSelected ? AppColors.surface : AppColors.grey600,
                    fontWeight: FontWeight.w800,
                    fontSize: 11,
                    letterSpacing: 1.2,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildCategoryTabs(List<dynamic> categories) {
    return Container(
      height: 52,
      color: AppColors.surface,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        children: [
          _tabItem(
            'All',
            widget.selectedCategoryId == null,
            () => widget.onCategoryTap(null),
          ),
          ...categories.map(
            (c) => _tabItem(
              c.name,
              widget.selectedCategoryId == c.id,
              () => widget.onCategoryTap(c.id),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProductCardWithModifiers(dynamic product) {
    return PosProductCard(
      product: product,
      onTap: () => _showModifierDialog(product),
      size: PosCardSize.large,
      showSku: true,
    );
  }

  void _showModifierDialog(dynamic product) {
    final List<String> selectedModifiers = [];
    final String currentCourse = _courses[_selectedCourse];

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: AppColors.surface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'CUSTOMIZE ITEM',
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 12,
                  letterSpacing: 1,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                product.name,
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 20,
                  color: AppColors.text,
                ),
              ),
            ],
          ),
          content: SizedBox(
            width: 400,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildModifierSection(
                    'SIZE / PORTION',
                    ['Regular', 'Large', 'Extra Large'],
                    selectedModifiers,
                    setDialogState,
                    isSingle: true,
                  ),
                  const SizedBox(height: 16),
                  _buildModifierSection(
                    'TEMPERATURE',
                    ['Hot', 'Cold', 'Iced'],
                    selectedModifiers,
                    setDialogState,
                    isSingle: true,
                  ),
                  const SizedBox(height: 16),
                  _buildModifierSection(
                    'EXTRAS & TOPPINGS',
                    ['Extra Cheese', 'Bacon', 'Avocado', 'Mushrooms', 'Jalapenos'],
                    selectedModifiers,
                    setDialogState,
                  ),
                  const SizedBox(height: 24),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.background,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppColors.grey100),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.timer_outlined, size: 16, color: AppColors.primary),
                        const SizedBox(width: 8),
                        Text(
                          'COURSE: ${currentCourse.toUpperCase()}',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.5,
                            color: AppColors.text,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                'CANCEL',
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  color: AppColors.grey400,
                  letterSpacing: 1,
                ),
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: AppColors.surface,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: () {
                widget.cartNotifier.addProduct(
                  product,
                  modifiers: selectedModifiers.isNotEmpty ? selectedModifiers : null,
                  course: currentCourse,
                );
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('${product.name} added to $currentCourse'),
                    backgroundColor: AppColors.primary,
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              },
              child: const Text(
                'ADD TO ORDER',
                style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildModifierSection(
    String title,
    List<String> options,
    List<String> selected,
    StateSetter setDialogState, {
    bool isSingle = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            fontWeight: FontWeight.w900,
            fontSize: 11,
            letterSpacing: 1,
            color: AppColors.text.withValues(alpha: 0.5),
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: options.map((option) {
            final isSelected = selected.contains(option);
            return InkWell(
              onTap: () {
                setDialogState(() {
                  if (isSelected) {
                    selected.remove(option);
                  } else {
                    if (isSingle) {
                      // Remove other options from this set if single select
                      selected.removeWhere((item) => options.contains(item));
                    }
                    selected.add(option);
                  }
                });
              },
              borderRadius: BorderRadius.circular(8),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: isSelected ? AppColors.primary : AppColors.surface,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isSelected ? AppColors.primary : AppColors.grey200,
                  ),
                ),
                child: Text(
                  option,
                  style: TextStyle(
                    color: isSelected ? AppColors.surface : AppColors.text,
                    fontWeight: isSelected ? FontWeight.w900 : FontWeight.w600,
                    fontSize: 12,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildCustomerTableSection() {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      color: AppColors.background,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.person_outline,
                size: 20,
                color: Color(0xFF64748B),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  widget.cartState.selectedCustomer?.name ?? 'WALK-IN CUSTOMER',
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 13,
                    letterSpacing: 0.5,
                    color: AppColors.text,
                  ),
                ),
              ),
              if (widget.cartState.selectedCustomer != null)
                IconButton(
                  onPressed: () => widget.cartNotifier.setCustomer(null),
                  icon: const Icon(Icons.close, size: 18, color: Colors.red),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  tooltip: 'Remove Customer',
                ),
              TextButton.icon(
                onPressed: widget.onShowAddCustomerDialog,
                icon: const Icon(Icons.add, size: 16),
                label: const Text('CUSTOMER', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildOrderTypeSelector() {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.background,
        border: Border(top: BorderSide(color: AppColors.grey100)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'SELECT ORDER TYPE',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w900,
              letterSpacing: 1,
              color: AppColors.text.withValues(alpha: 0.5),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: List.generate(_orderTypes.length, (index) {
              final isSelected = _orderType == index;
              return Expanded(
                child: Padding(
                  padding: EdgeInsets.only(
                    right: index == _orderTypes.length - 1 ? 0 : 8,
                  ),
                  child: InkWell(
                    onTap: () {
                      setState(() => _orderType = index);
                      if (index == 2) {
                        _showDeliveryBoyDialog();
                      } else {
                        _deliveryBoyName = null;
                      }
                    },
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        color: isSelected ? AppColors.primary : AppColors.surface,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: isSelected ? AppColors.primary : AppColors.grey200,
                        ),
                        boxShadow: isSelected ? [
                          BoxShadow(
                            color: AppColors.primary.withValues(alpha: 0.2),
                            blurRadius: 8,
                            offset: const Offset(0, 4),
                          )
                        ] : null,
                      ),
                      child: Column(
                        children: [
                          Icon(
                            index == 0 ? Icons.restaurant : index == 1 ? Icons.shopping_bag : Icons.delivery_dining,
                            size: 20,
                            color: isSelected ? AppColors.surface : AppColors.grey400,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _orderTypes[index].toUpperCase(),
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w900,
                              color: isSelected ? AppColors.surface : AppColors.text,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            }),
          ),
          if (_orderType == 2 && _deliveryBoyName != null)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: AppColors.primary.withValues(alpha: 0.1)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.person, size: 14, color: AppColors.primary),
                    const SizedBox(width: 8),
                    Text(
                      'DELIVERY BOY: $_deliveryBoyName',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        color: AppColors.primary,
                      ),
                    ),
                    const Spacer(),
                    InkWell(
                      onTap: _showDeliveryBoyDialog,
                      child: const Icon(Icons.edit, size: 14, color: AppColors.primary),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  void _showDeliveryBoyDialog() {
    final controller = TextEditingController(text: _deliveryBoyName);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Text(
          'DELIVERY DETAILS',
          style: TextStyle(fontWeight: FontWeight.w900, fontSize: 14, color: AppColors.text),
        ),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(
            labelText: 'Delivery Boy Name',
            labelStyle: TextStyle(fontSize: 12, color: AppColors.grey400),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            prefixIcon: const Icon(Icons.person_outline),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('CANCEL', style: TextStyle(color: AppColors.grey400, fontWeight: FontWeight.bold)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
            onPressed: () {
              setState(() => _deliveryBoyName = controller.text);
              Navigator.pop(context);
            },
            child: const Text('CONFIRM', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Widget _buildOrderTypeBadge() {
    String orderTypeText = _orderTypes[_orderType];
    if (_orderType == 2 && _deliveryBoyName != null) {
      orderTypeText += ' - $_deliveryBoyName';
    }
    if (_showCoursePanel) {
      orderTypeText += ' • ${_courses[_selectedCourse]} Course';
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
      color: AppColors.primary.withValues(alpha: 0.08),
      child: Row(
        children: [
          Icon(
            _orderType == 0 ? Icons.restaurant : _orderType == 1 ? Icons.shopping_bag : Icons.delivery_dining,
            size: 16, 
            color: AppColors.primary
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'ORDER: $orderTypeText'.toUpperCase(),
              style: TextStyle(
                fontWeight: FontWeight.w900,
                color: AppColors.primary,
                fontSize: 11,
                letterSpacing: 1,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCourseBasedCartItems() {
    // Filter items by selected course if course management is enabled
    final filteredItems = _showCoursePanel
        ? widget.cartState.items.where((item) {
            // In production, items would have course property
            // This is a sample filter logic
            return true;
          }).toList()
        : widget.cartState.items;

    return ListView.separated(
      padding: const EdgeInsets.all(12),
      itemCount: filteredItems.length,
      separatorBuilder: (context, index) => const SizedBox(height: 8),
      itemBuilder: (context, i) => PosCartItemTile(
        item: filteredItems[i],
        cartNotifier: widget.cartNotifier,
        onShowDiscount: widget.onShowItemDiscount,
      ),
    );
  }

  Widget _buildEmptyCart() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.restaurant_menu, size: 64, color: AppColors.grey200),
          const SizedBox(height: AppSpacing.md),
          Text(
            'Cart is Empty',
            style: TextStyle(
              color: AppColors.text.withValues(alpha: 0.4),
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Select items from the menu',
            style: TextStyle(color: AppColors.grey400, fontSize: 14),
          ),
        ],
      ),
    );
  }

  Widget _buildOrderInstructions() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Column(
        children: [
          TextField(
            controller: _notesController,
            maxLines: 2,
            decoration: InputDecoration(
              hintText: 'Order notes (e.g., "No onions", "Extra spicy")...',
              hintStyle: const TextStyle(fontSize: 12),
              prefixIcon: const Icon(Icons.note, size: 18),
              contentPadding: const EdgeInsets.all(10),
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
          const SizedBox(height: 8),
          if (_orderType == 0)
            TextField(
              controller: _cookingInstructionsController,
              maxLines: 1,
              decoration: InputDecoration(
                hintText: 'Cooking instructions for kitchen...',
                hintStyle: const TextStyle(fontSize: 12),
                prefixIcon: const Icon(Icons.kitchen, size: 18),
                contentPadding: const EdgeInsets.all(10),
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
        ],
      ),
    );
  }

  Widget _buildQuickActionsBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _quickActionButton(
            icon: Icons.receipt,
            label: 'Split Bill',
            onTap: widget.onSplitBill,
          ),
          _quickActionButton(
            icon: Icons.print,
            label: 'Print',
            onTap: widget.onPrintReceipt,
          ),
          _quickActionButton(
            icon: Icons.pause_circle_outline,
            label: 'Hold',
            onTap: widget.onOrderHold,
          ),
          _quickActionButton(
            icon: Icons.history,
            label: 'Recall',
            onTap: widget.onRecallOrder,
          ),
        ],
      ),
    );
  }

  Widget _quickActionButton({
    required IconData icon,
    required String label,
    VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
          Icon(icon, size: 22, color: AppColors.accent),
            const SizedBox(height: 6),
            Text(
              label.toUpperCase(),
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.5,
                color: AppColors.accent,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _tabItem(String label, bool active, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        alignment: Alignment.center,
        margin: const EdgeInsets.only(right: AppSpacing.sm),
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
        decoration: BoxDecoration(
          color: active ? AppColors.primary : AppColors.surface,
          borderRadius: BorderRadius.circular(8),
          boxShadow: active ? AppShadows.md : null,
          border: Border.all(color: active ? AppColors.primary : AppColors.grey200),
        ),
        child: Text(
          label.toUpperCase(),
          style: TextStyle(
            fontWeight: FontWeight.w900,
            color: active ? AppColors.surface : AppColors.grey600,
            fontSize: 11,
            letterSpacing: 1.1,
          ),
        ),
      ),
    );
  }
}

// Modifier Model
class Modifier {
  final String id;
  final String name;
  final double price;
  final bool isRequired;

  Modifier({
    required this.id,
    required this.name,
    this.price = 0,
    this.isRequired = false,
  });
}
