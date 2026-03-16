import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ezo/core/database/app_database.dart';
import 'package:ezo/features/pos/state/cart_state.dart';

/// Base class for all POS layout widgets.
///
/// HOW TO CREATE A NEW LAYOUT:
/// 1. Create a new file in features/pos/layouts/
/// 2. Extend [BasePosLayout] and implement [createState]
/// 3. Your state class should extend [BasePosLayoutState]
/// 4. Override [build] to arrange the UI using the provided data
/// 5. Add the layout to [PosLayoutType] enum in pos_layout_provider.dart
/// 6. Add a case for it in the switch statement in pos_screen.dart
///
/// Available data via widget properties:
/// - [cartState]: Current cart with items, totals, discounts
/// - [cartNotifier]: Mutate cart (add/remove/update items)
/// - [products]: Async list of products (use .when() to handle loading/error)
/// - [categories]: Async list of categories
/// - [selectedCategoryId]: Currently filtered category (null = all)
/// - [searchQuery]: Current product search text
/// - Callbacks: [onProductTap], [onCategoryTap], [onSearch],
///   [onCheckout], [onOpenInvoiceSettings], [onOpenSalesHistory],
///   [onShowAddCustomerDialog]
abstract class BasePosLayout extends ConsumerStatefulWidget {
  final CartState cartState;
  final CartNotifier cartNotifier;
  final AsyncValue<List<ProductEntity>> products;
  final AsyncValue<List<CategoryEntity>> categories;
  final int? selectedCategoryId;
  final String searchQuery;

  // Callbacks — keeps business logic in PosScreen
  final void Function(ProductEntity product) onProductTap;
  final void Function(int? categoryId) onCategoryTap;
  final void Function(String query) onSearch;
  final void Function({bool shouldSave}) onCheckout;
  final VoidCallback onOpenInvoiceSettings;
  final VoidCallback onOpenSalesHistory;
  final VoidCallback onShowAddCustomerDialog;
  final void Function(CartItem item) onShowItemDiscount;
  final void Function(double discount, bool isPercent) onSetOverallDiscount;
  final VoidCallback onReset;
  final VoidCallback onBack;

  const BasePosLayout({
    super.key,
    required this.cartState,
    required this.cartNotifier,
    required this.products,
    required this.categories,
    required this.selectedCategoryId,
    required this.searchQuery,
    required this.onProductTap,
    required this.onCategoryTap,
    required this.onSearch,
    required this.onCheckout,
    required this.onOpenInvoiceSettings,
    required this.onOpenSalesHistory,
    required this.onShowAddCustomerDialog,
    required this.onShowItemDiscount,
    required this.onSetOverallDiscount,
    required this.onReset,
    required this.onBack,
  });
}

/// Optional base state — layouts can extend this for convenience.
abstract class BasePosLayoutState<T extends BasePosLayout>
    extends ConsumerState<T> {}
