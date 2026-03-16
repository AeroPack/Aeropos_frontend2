import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ezo/features/pos/layouts/base_pos_layout.dart';
import 'package:ezo/features/pos/widgets/common/product_card.dart';
import 'package:ezo/features/pos/widgets/common/cart_item_tile.dart';
import 'package:ezo/features/pos/widgets/common/totals_display.dart';
import 'package:ezo/features/pos/widgets/pos_layout_selector.dart';

/// Restaurant layout — order type selector, large images, order notes.
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
  });

  @override
  ConsumerState<RestaurantLayout> createState() => _RestaurantLayoutState();
}

class _RestaurantLayoutState extends BasePosLayoutState<RestaurantLayout> {
  int _orderType = 0; // 0=Dine In, 1=Takeaway, 2=Delivery
  final _searchController = TextEditingController();
  final _notesController = TextEditingController();

  static const _orderTypes = ['Dine In', 'Takeaway', 'Delivery'];

  @override
  void initState() {
    super.initState();
    _searchController.text = widget.searchQuery;
  }

  @override
  void dispose() {
    _searchController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        // Left — products
        Expanded(
          flex: 6,
          child: Column(
            children: [
              // Order type sub-toolbar
              Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: List.generate(_orderTypes.length, (i) {
                    final selected = _orderType == i;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text(
                          _orderTypes[i],
                          style: TextStyle(
                            color: selected
                                ? Colors.white
                                : Colors.grey.shade700,
                            fontWeight: FontWeight.w600,
                            fontSize: 12,
                          ),
                        ),
                        selected: selected,
                        selectedColor: const Color(0xFF007AFF),
                        backgroundColor: const Color(0xFFF1F5F9),
                        onSelected: (_) => setState(() => _orderType = i),
                      ),
                    );
                  }),
                ),
              ),
              // Category tabs
              widget.categories.when(
                data: (cats) => Container(
                  height: 48,
                  color: Colors.white,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    children: [
                      _tabItem(
                        'All',
                        widget.selectedCategoryId == null,
                        () => widget.onCategoryTap(null),
                      ),
                      ...cats.map(
                        (c) => _tabItem(
                          c.name,
                          widget.selectedCategoryId == c.id,
                          () => widget.onCategoryTap(c.id),
                        ),
                      ),
                    ],
                  ),
                ),
                loading: () => const SizedBox(height: 48),
                error: (e, _) =>
                    SizedBox(height: 48, child: Center(child: Text('$e'))),
              ),

              // Product grid — 2 columns, large images
              Expanded(
                child: widget.products.when(
                  data: (products) => GridView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          childAspectRatio: 0.9,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                        ),
                    itemCount: products.length,
                    itemBuilder: (_, i) => PosProductCard(
                      product: products[i],
                      onTap: () => widget.onProductTap(products[i]),
                      size: PosCardSize.large,
                      showSku: true,
                    ),
                  ),
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (e, _) => Center(child: Text('Error: $e')),
                ),
              ),
            ],
          ),
        ),

        // Right — cart with order notes
        Container(
          width: 380,
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 15,
              ),
            ],
          ),
          child: Column(
            children: [
              // Customer info
              Container(
                padding: const EdgeInsets.all(12),
                color: const Color(0xFFF8FAFC),
                child: Row(
                  children: [
                    const Icon(
                      Icons.person_outline,
                      size: 20,
                      color: Color(0xFF64748B),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        widget.cartState.selectedCustomer?.name ??
                            'Walk-in Customer',
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                    ),
                    TextButton.icon(
                      onPressed: widget.onShowAddCustomerDialog,
                      icon: const Icon(Icons.add, size: 16),
                      label: const Text('Add', style: TextStyle(fontSize: 12)),
                    ),
                  ],
                ),
              ),
              // Order type badge
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                color: const Color(0xFF007AFF).withValues(alpha: 0.1),
                child: Text(
                  'Order: ${_orderTypes[_orderType]}',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF007AFF),
                    fontSize: 13,
                  ),
                ),
              ),
              const Divider(height: 1),
              // Cart items
              Expanded(
                child: widget.cartState.items.isEmpty
                    ? const Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.restaurant_menu,
                              size: 48,
                              color: Colors.grey,
                            ),
                            SizedBox(height: 8),
                            Text(
                              'No items in order',
                              style: TextStyle(color: Colors.grey),
                            ),
                          ],
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.all(12),
                        itemCount: widget.cartState.items.length,
                        separatorBuilder: (context, index) =>
                            const SizedBox(height: 8),
                        itemBuilder: (context, i) => PosCartItemTile(
                          item: widget.cartState.items[i],
                          cartNotifier: widget.cartNotifier,
                          onShowDiscount: widget.onShowItemDiscount,
                        ),
                      ),
              ),
              // Order notes
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: TextField(
                  controller: _notesController,
                  maxLines: 2,
                  decoration: InputDecoration(
                    hintText: 'Order notes...',
                    hintStyle: const TextStyle(fontSize: 13),
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
              ),
              const SizedBox(height: 4),
              PosTotalsDisplay(
                cartState: widget.cartState,
                onCheckout: () => widget.onCheckout(shouldSave: true),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _tabItem(String label, bool active, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        alignment: Alignment.center,
        margin: const EdgeInsets.only(right: 4),
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: active ? const Color(0xFF007AFF) : Colors.transparent,
              width: 2,
            ),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontWeight: active ? FontWeight.bold : FontWeight.w500,
            color: active ? const Color(0xFF007AFF) : Colors.grey.shade600,
            fontSize: 13,
          ),
        ),
      ),
    );
  }
}
