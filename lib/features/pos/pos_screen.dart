import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';
import 'package:ezo/features/pos/state/cart_state.dart';
import 'package:ezo/features/pos/state/pos_category_state.dart';
import 'package:ezo/features/pos/providers/pos_layout_provider.dart';
import 'package:ezo/features/pos/layouts/compact_layout.dart';
import 'package:ezo/features/pos/layouts/restaurant_layout.dart';
import 'package:ezo/features/pos/layouts/retail_layout.dart';
import 'package:ezo/features/pos/layouts/touch_layout.dart';
import 'package:ezo/features/pos/layouts/dual_screen_layout.dart';
import 'package:ezo/features/pos/widgets/pos_layout_selector.dart';
import 'package:ezo/core/database/app_database.dart';
import '../../core/models/sale.dart';
import '../../core/models/invoice_template.dart';
import '../../core/services/invoice_service.dart';
import '../inventory/reports/invoice_settings_screen.dart';
import '../../core/widgets/pos_toast.dart';
import '../../core/widgets/customer_form_dialog.dart';
import '../../core/di/service_locator.dart';
import '../../core/exceptions/sale_validation_exception.dart';
import '../sales/screens/invoice_preview_screen.dart';
import '../../core/widgets/master_header.dart';

class PosScreen extends ConsumerStatefulWidget {
  const PosScreen({super.key});
  @override
  ConsumerState<PosScreen> createState() => _PosScreenState();
}

class _PosScreenState extends ConsumerState<PosScreen> {
  final _uuid = const Uuid();

  @override
  void initState() {
    super.initState();
    ServiceLocator.instance.syncService.pull();
  }

  Future<void> _handleCheckout({bool shouldSave = true}) async {
    final cartState = ref.read(cartProvider);
    if (cartState.items.isEmpty) return;

    final sale = Sale(
      uuid: _uuid.v4(),
      invoiceNumber: "INV-${DateTime.now().millisecondsSinceEpoch}",
      customerId: cartState.selectedCustomer?.id,
      items: cartState.items
          .map(
            (cartItem) => SaleItem(
              uuid: _uuid.v4(),
              productId: cartItem.product.id,
              product: cartItem.product,
              quantity: cartItem.quantity,
              unitPrice: cartItem.product.price,
              discount: cartItem.manualDiscount,
              total: cartItem.total,
            ),
          )
          .toList(),
      total: cartState.total,
      subtotal: cartState.subtotal,
      tax: cartState.taxAmount,
      discount: cartState.totalDiscount,
      createdAt: DateTime.now(),
    );

    try {
      if (shouldSave) {
        await ServiceLocator.instance.saleRepository.createSale(sale);
      }
      final template = ref.read(invoiceTemplateProvider);

      if (!mounted) return;
      showDialog(
        context: context,
        barrierDismissible: true,
        barrierColor: Colors.black.withValues(alpha: 0.5),
        builder: (context) => InvoicePreviewScreen(
          invoiceNumber: sale.invoiceNumber,
          onLayout: (format) async {
            final pdf = await InvoiceService().generateInvoice(sale, template);
            return pdf.save();
          },
          onPrintComplete: () {
            if (shouldSave) {
              ref.read(cartProvider.notifier).clearCart();
              PosToast.showSuccess(context, "Checkout completed");
            }
            if (mounted) Navigator.pop(context);
          },
        ),
      );
    } on SaleValidationException catch (e) {
      if (!mounted) return;
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Invalid Products'),
          content: Text(e.message),
          actions: [
            TextButton(
              onPressed: () async {
                Navigator.pop(context);
                PosToast.showInfo(context, 'Syncing products...');
                await ServiceLocator.instance.syncService.syncProducts();
              },
              child: const Text('Sync Products'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('OK'),
            ),
          ],
        ),
      );
    } catch (e) {
      if (mounted) PosToast.showError(context, "Failed to process sale: $e");
    }
  }

  void _openInvoiceSettings() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const InvoiceSettingsScreen()),
    );
  }

  void _openSalesHistory() => context.go('/sales-history');

  void _showAddCustomerDialog() {
    showDialog(
      context: context,
      builder: (context) => CustomerFormDialog(
        onSubmit:
            ({
              required name,
              phone,
              address,
              required creditLimit,
              email,
            }) async {
              final customer = await ServiceLocator.instance.customerViewModel
                    .addCustomer(
                      name: name,
                      phone: phone,
                      email: email,
                      address: address,
                      creditLimit: creditLimit,
                    );
                if (!context.mounted) return;
                ref.read(cartProvider.notifier).setCustomer(customer);
                PosToast.showSuccess(context, "Customer created and selected");
              },
      ),
    );
  }

  void _showItemDiscountDialog(CartItem item) {
    bool isPercent = item.isPercentDiscount;
    final controller = TextEditingController(
      text: item.manualDiscount.toString(),
    );

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text('Discount for ${item.product.name}'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ChoiceChip(
                    label: const Text("Rs"),
                    selected: !isPercent,
                    onSelected: (val) => setState(() => isPercent = !val),
                  ),
                  const SizedBox(width: 12),
                  ChoiceChip(
                    label: const Text("%"),
                    selected: isPercent,
                    onSelected: (val) => setState(() => isPercent = val),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              TextField(
                controller: controller,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: isPercent
                      ? 'Discount Percentage (%)'
                      : 'Discount Amount (Rs)',
                  prefixText: isPercent ? null : 'Rs ',
                  suffixText: isPercent ? ' %' : null,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                final d = double.tryParse(controller.text) ?? 0.0;
                ref
                    .read(cartProvider.notifier)
                    .updateItemDiscount(item.product, d, isPercent);
                Navigator.pop(context);
              },
              child: const Text('Apply'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final layoutType = ref.watch(posLayoutProvider);
    final cartState = ref.watch(cartProvider);
    final cartNotifier = ref.read(cartProvider.notifier);
    final products = ref.watch(posProductListProvider);
    final categories = ref.watch(categoryStreamProvider);
    final selectedCategoryId = ref.watch(selectedCategoryProvider);
    final searchQuery = ref.watch(productSearchProvider);

    final String layoutTitle = switch (layoutType) {
      PosLayoutType.compact => "Compact POS",
      PosLayoutType.restaurant => "Dine POS",
      PosLayoutType.retail => "Retail POS",
      PosLayoutType.touch => "Touch POS",
      PosLayoutType.dualScreen => "Dual Screen POS",
    };

    onSearch(q) => ref.read(productSearchProvider.notifier).state = q;
    void onBack() => context.go('/dashboard');

    return Scaffold(
      appBar: MasterHeader(
        showSidebarToggle: false,
        hidePosButton: true,
        title: Text(
          layoutTitle,
          style: const TextStyle(
            color: Color(0xFF0F172A),
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        searchQuery: searchQuery,
        onSearch: onSearch,
        customActions: [
          IconButton(
            onPressed: onBack,
            icon: const Icon(Icons.arrow_back, color: Colors.grey),
          ),
          // Layout Selector as part of the header actions
          const PosLayoutSelector(),
          const SizedBox(width: 8),
        ],
      ),
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 300),
        child: _buildSelectedLayout(
          layoutType,
          cartState,
          cartNotifier,
          products,
          categories,
          selectedCategoryId,
          searchQuery,
          onSearch,
          onBack,
        ),
      ),
    );
  }

  Widget _buildSelectedLayout(
    PosLayoutType type,
    CartState cartState,
    CartNotifier cartNotifier,
    AsyncValue<List<ProductEntity>> products,
    AsyncValue<List<CategoryEntity>> categories,
    int? selectedCategoryId,
    String searchQuery,
    void Function(String) onSearch,
    VoidCallback onBack,
  ) {
    void onProductTap(p) => cartNotifier.addProduct(p);
    onCategoryTap(id) =>
        ref.read(selectedCategoryProvider.notifier).state = id;
    Future<void> onCheckout({bool shouldSave = true}) =>
        _handleCheckout(shouldSave: shouldSave);
    void onSetOverallDiscount(d, p) =>
        cartNotifier.setOverallDiscount(d, p);
    void onReset() => cartNotifier.clearCart();

    switch (type) {
      case PosLayoutType.compact:
        return CompactLayout(
          key: const ValueKey('compact'),
          cartState: cartState,
          cartNotifier: cartNotifier,
          products: products,
          categories: categories,
          selectedCategoryId: selectedCategoryId,
          searchQuery: searchQuery,
          onProductTap: onProductTap,
          onCategoryTap: onCategoryTap,
          onSearch: onSearch,
          onCheckout: onCheckout,
          onOpenInvoiceSettings: _openInvoiceSettings,
          onOpenSalesHistory: _openSalesHistory,
          onShowAddCustomerDialog: _showAddCustomerDialog,
          onShowItemDiscount: _showItemDiscountDialog,
          onSetOverallDiscount: onSetOverallDiscount,
          onReset: onReset,
          onBack: onBack,
        );
      case PosLayoutType.restaurant:
        return RestaurantLayout(
          key: const ValueKey('restaurant'),
          cartState: cartState,
          cartNotifier: cartNotifier,
          products: products,
          categories: categories,
          selectedCategoryId: selectedCategoryId,
          searchQuery: searchQuery,
          onProductTap: onProductTap,
          onCategoryTap: onCategoryTap,
          onSearch: onSearch,
          onCheckout: onCheckout,
          onOpenInvoiceSettings: _openInvoiceSettings,
          onOpenSalesHistory: _openSalesHistory,
          onShowAddCustomerDialog: _showAddCustomerDialog,
          onShowItemDiscount: _showItemDiscountDialog,
          onSetOverallDiscount: onSetOverallDiscount,
          onReset: onReset,
          onBack: onBack,
        );
      case PosLayoutType.retail:
        return RetailLayout(
          key: const ValueKey('retail'),
          cartState: cartState,
          cartNotifier: cartNotifier,
          products: products,
          categories: categories,
          selectedCategoryId: selectedCategoryId,
          searchQuery: searchQuery,
          onProductTap: onProductTap,
          onCategoryTap: onCategoryTap,
          onSearch: onSearch,
          onCheckout: onCheckout,
          onOpenInvoiceSettings: _openInvoiceSettings,
          onOpenSalesHistory: _openSalesHistory,
          onShowAddCustomerDialog: _showAddCustomerDialog,
          onShowItemDiscount: _showItemDiscountDialog,
          onSetOverallDiscount: onSetOverallDiscount,
          onReset: onReset,
          onBack: onBack,
        );
      case PosLayoutType.touch:
        return TouchLayout(
          key: const ValueKey('touch'),
          cartState: cartState,
          cartNotifier: cartNotifier,
          products: products,
          categories: categories,
          selectedCategoryId: selectedCategoryId,
          searchQuery: searchQuery,
          onProductTap: onProductTap,
          onCategoryTap: onCategoryTap,
          onSearch: onSearch,
          onCheckout: onCheckout,
          onOpenInvoiceSettings: _openInvoiceSettings,
          onOpenSalesHistory: _openSalesHistory,
          onShowAddCustomerDialog: _showAddCustomerDialog,
          onShowItemDiscount: _showItemDiscountDialog,
          onSetOverallDiscount: onSetOverallDiscount,
          onReset: onReset,
          onBack: onBack,
        );
      case PosLayoutType.dualScreen:
        return DualScreenLayout(
          key: const ValueKey('dual'),
          cartState: cartState,
          cartNotifier: cartNotifier,
          products: products,
          categories: categories,
          selectedCategoryId: selectedCategoryId,
          searchQuery: searchQuery,
          onProductTap: onProductTap,
          onCategoryTap: onCategoryTap,
          onSearch: onSearch,
          onCheckout: onCheckout,
          onOpenInvoiceSettings: _openInvoiceSettings,
          onOpenSalesHistory: _openSalesHistory,
          onShowAddCustomerDialog: _showAddCustomerDialog,
          onShowItemDiscount: _showItemDiscountDialog,
          onSetOverallDiscount: onSetOverallDiscount,
          onReset: onReset,
          onBack: onBack,
        );
    }
  }
}
