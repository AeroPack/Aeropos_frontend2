import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ezo/features/pos/layouts/base_pos_layout.dart';
import 'package:ezo/features/pos/widgets/common/product_card.dart';
import 'package:ezo/features/pos/widgets/common/category_chip.dart';

/// Touch layout — extra large buttons, number pad, high contrast.
/// Cart on the left (35%), products on right with big tiles.
class TouchLayout extends BasePosLayout {
  const TouchLayout({
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
  ConsumerState<TouchLayout> createState() => _TouchLayoutState();
}

class _TouchLayoutState extends BasePosLayoutState<TouchLayout> {
  final _searchController = TextEditingController();
  String _manualEntry = '';

  @override
  void initState() {
    super.initState();
    _searchController.text = widget.searchQuery;
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _onNumPadTap(String val) {
    setState(() {
      if (val == 'C') {
        _manualEntry = '';
      } else if (val == '⌫') {
        if (_manualEntry.isNotEmpty) {
          _manualEntry = _manualEntry.substring(0, _manualEntry.length - 1);
        }
      } else {
        _manualEntry += val;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        // LEFT — Cart (35%)
        Container(
          width: MediaQuery.of(context).size.width * 0.35,
          color: const Color(0xFF0F172A),
          child: Column(
            children: [
              // Header
              Container(
                padding: const EdgeInsets.all(16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'ORDER',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                        letterSpacing: 1.5,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF007AFF),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '${widget.cartState.items.length} items',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              // Cart items
              Expanded(
                child: widget.cartState.items.isEmpty
                    ? const Center(
                        child: Text(
                          'Tap products to add',
                          style: TextStyle(color: Colors.white54, fontSize: 16),
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        itemCount: widget.cartState.items.length,
                        separatorBuilder: (context, index) =>
                            const SizedBox(height: 8),
                        itemBuilder: (context, i) {
                          final item = widget.cartState.items[i];
                          return Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        item.product.name,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 15,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        'Rs ${item.total.toStringAsFixed(0)}',
                                        style: const TextStyle(
                                          color: Color(0xFF00A78E),
                                          fontWeight: FontWeight.w600,
                                          fontSize: 14,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                // Large qty controls
                                Row(
                                  children: [
                                    _touchBtn(
                                      Icons.remove,
                                      () => widget.cartNotifier.updateQuantity(
                                        item.product,
                                        item.quantity - 1,
                                      ),
                                    ),
                                    Padding(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                      ),
                                      child: Text(
                                        '${item.quantity}',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 20,
                                        ),
                                      ),
                                    ),
                                    _touchBtn(
                                      Icons.add,
                                      () => widget.cartNotifier.updateQuantity(
                                        item.product,
                                        item.quantity + 1,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          );
                        },
                      ),
              ),
              // Number pad
              Container(
                padding: const EdgeInsets.all(12),
                child: Column(
                  children: [
                    // Display
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      margin: const EdgeInsets.only(bottom: 8),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        _manualEntry.isEmpty ? '0' : _manualEntry,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'monospace',
                        ),
                        textAlign: TextAlign.right,
                      ),
                    ),
                    // Numpad grid
                    GridView.count(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      crossAxisCount: 3,
                      mainAxisSpacing: 6,
                      crossAxisSpacing: 6,
                      childAspectRatio: 2.2,
                      children: [
                        ...'789456123'
                            .split('')
                            .map((d) => _numKey(d, () => _onNumPadTap(d))),
                        _numKey(
                          'C',
                          () => _onNumPadTap('C'),
                          color: Colors.red.shade400,
                        ),
                        _numKey('0', () => _onNumPadTap('0')),
                        _numKey(
                          '⌫',
                          () => _onNumPadTap('⌫'),
                          color: Colors.orange.shade400,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              // Totals + checkout
              Container(
                padding: const EdgeInsets.all(12),
                decoration: const BoxDecoration(
                  border: Border(top: BorderSide(color: Colors.white24)),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'TOTAL',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          'Rs ${widget.cartState.total.toInt()}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      height: 60,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF16A34A),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onPressed: widget.cartState.items.isEmpty
                            ? null
                            : () => widget.onCheckout(shouldSave: true),
                        child: const Text(
                          'CHECKOUT',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 20,
                            letterSpacing: 1,
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

        // RIGHT — Products (65%)
        Expanded(
          child: Container(
            color: const Color(0xFFF8F9FA),
            child: Column(
              children: [
                // Optional: some padding
                const SizedBox(height: 8),
                // Category chips
                SizedBox(
                  height: 50,
                  child: widget.categories.when(
                    data: (cats) => ListView(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      children: [
                        PosCategoryChip(
                          name: 'All',
                          isActive: widget.selectedCategoryId == null,
                          onTap: () => widget.onCategoryTap(null),
                          icon: Icons.grid_view,
                        ),
                        const SizedBox(width: 8),
                        ...cats.map(
                          (c) => Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: PosCategoryChip(
                              name: c.name,
                              isActive: widget.selectedCategoryId == c.id,
                              onTap: () => widget.onCategoryTap(c.id),
                            ),
                          ),
                        ),
                      ],
                    ),
                    loading: () => const SizedBox(),
                    error: (e, _) => Center(child: Text('$e')),
                  ),
                ),
                const SizedBox(height: 8),
                // Product grid — 2 columns, big tiles (min 60px button height)
                Expanded(
                  child: widget.products.when(
                    data: (products) => GridView.builder(
                      padding: const EdgeInsets.all(12),
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            childAspectRatio: 1.2,
                            crossAxisSpacing: 12,
                            mainAxisSpacing: 12,
                          ),
                      itemCount: products.length,
                      itemBuilder: (context, i) => PosProductCard(
                        product: products[i],
                        onTap: () => widget.onProductTap(products[i]),
                        size: PosCardSize.large,
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
        ),
      ],
    );
  }

  Widget _touchBtn(IconData icon, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          border: Border.all(color: Colors.white30),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: Colors.white, size: 20),
      ),
    );
  }

  Widget _numKey(String label, VoidCallback onTap, {Color? color}) {
    return InkWell(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: color ?? Colors.white.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(8),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
      ),
    );
  }
}
