import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ezo/features/pos/state/cart_state.dart';
import 'package:ezo/features/pos/layouts/base_pos_layout.dart';
import 'package:ezo/features/pos/widgets/common/product_card.dart';
import 'package:ezo/features/pos/widgets/common/category_chip.dart';
import 'package:ezo/features/pos/widgets/common/totals_display.dart';

/// Retail layout — barcode input, 5-col minimal grid, receipt-style cart.
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
  final _barcodeController = TextEditingController();
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _searchController.text = widget.searchQuery;
  }

  @override
  void dispose() {
    _barcodeController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _handleBarcode(String barcode) {
    if (barcode.isEmpty) return;
    widget.products.whenData((products) {
      final match = products.where(
        (p) => p.sku?.toLowerCase() == barcode.toLowerCase(),
      );
      if (match.isNotEmpty) {
        widget.onProductTap(match.first);
        _barcodeController.clear();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Barcode sub-toolbar
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              SizedBox(
                width: 300,
                height: 40,
                child: TextField(
                  controller: _barcodeController,
                  onSubmitted: _handleBarcode,
                  decoration: InputDecoration(
                    hintText: 'Scan SKU...',
                    hintStyle: const TextStyle(fontSize: 13),
                    prefixIcon: const Icon(
                      Icons.qr_code_scanner,
                      color: Color(0xFF007AFF),
                      size: 20,
                    ),
                    contentPadding: const EdgeInsets.symmetric(vertical: 0),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                    ),
                    filled: true,
                    fillColor: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ),

        // Main body
        Expanded(
          child: Row(
            children: [
              // Products (left)
              Expanded(
                flex: 6,
                child: Column(
                  children: [
                    // Category chips
                    SizedBox(
                      height: 44,
                      child: widget.categories.when(
                        data: (cats) => ListView(
                          scrollDirection: Axis.horizontal,
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          children: [
                            PosCategoryChip(
                              name: 'All',
                              isActive: widget.selectedCategoryId == null,
                              onTap: () => widget.onCategoryTap(null),
                            ),
                            const SizedBox(width: 6),
                            ...cats.map(
                              (c) => Padding(
                                padding: const EdgeInsets.only(right: 6),
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
                    // 5-column grid
                    Expanded(
                      child: widget.products.when(
                        data: (products) => GridView.builder(
                          padding: const EdgeInsets.all(8),
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 5,
                                childAspectRatio: 0.9,
                                crossAxisSpacing: 8,
                                mainAxisSpacing: 8,
                              ),
                          itemCount: products.length,
                          itemBuilder: (_, i) => PosProductCard(
                            product: products[i],
                            onTap: () => widget.onProductTap(products[i]),
                            size: PosCardSize.small,
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

              // Receipt-style cart (right)
              Container(
                width: 360,
                decoration: BoxDecoration(
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 10,
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    // Receipt header
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      color: const Color(0xFF1E293B),
                      child: const Text(
                        'RECEIPT',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 2,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    // Receipt items
                    Expanded(
                      child: widget.cartState.items.isEmpty
                          ? const Center(
                              child: Text(
                                'No items',
                                style: TextStyle(color: Colors.grey),
                              ),
                            )
                          : ListView.builder(
                              padding: const EdgeInsets.all(12),
                              itemCount: widget.cartState.items.length,
                              itemBuilder: (_, i) {
                                final item = widget.cartState.items[i];
                                return _receiptLine(item);
                              },
                            ),
                    ),
                    PosTotalsDisplay(
                      cartState: widget.cartState,
                      compact: true,
                    ),
                    // Quick payment buttons
                    Padding(
                      padding: const EdgeInsets.all(12),
                      child: Row(
                        children: [
                          Expanded(
                            child: _payBtn(
                              'Cash',
                              Icons.money,
                              const Color(0xFF16A34A),
                              () => widget.onCheckout(shouldSave: true),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _payBtn(
                              'Card',
                              Icons.credit_card,
                              const Color(0xFF007AFF),
                              () => widget.onCheckout(shouldSave: true),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _payBtn(
                              'UPI',
                              Icons.qr_code,
                              const Color(0xFF7C3AED),
                              () => widget.onCheckout(shouldSave: true),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _receiptLine(CartItem item) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: Text(
              item.product.name,
              style: const TextStyle(fontSize: 13, fontFamily: 'monospace'),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Text(
            'x${item.quantity}',
            style: const TextStyle(
              fontSize: 12,
              color: Colors.grey,
              fontFamily: 'monospace',
            ),
          ),
          const SizedBox(width: 12),
          Text(
            'Rs ${item.total.toStringAsFixed(0)}',
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              fontFamily: 'monospace',
            ),
          ),
        ],
      ),
    );
  }

  Widget _payBtn(String label, IconData icon, Color color, VoidCallback onTap) {
    final disabled = widget.cartState.items.isEmpty;
    return ElevatedButton.icon(
      onPressed: disabled ? null : onTap,
      icon: Icon(icon, size: 18),
      label: Text(label, style: const TextStyle(fontSize: 12)),
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }
}
