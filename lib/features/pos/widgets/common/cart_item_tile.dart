import 'package:flutter/material.dart';
import 'package:ezo/features/pos/state/cart_state.dart';
import 'package:ezo/core/widgets/product_image.dart';

/// Reusable cart item tile for POS layouts.
/// Set [compact] to true for narrow cart panels.
class PosCartItemTile extends StatelessWidget {
  final CartItem item;
  final CartNotifier cartNotifier;
  final void Function(CartItem item) onShowDiscount;
  final bool compact;

  const PosCartItemTile({
    super.key,
    required this.item,
    required this.cartNotifier,
    required this.onShowDiscount,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    if (compact) return _buildCompact(context);
    return _buildNormal(context);
  }

  Widget _buildCompact(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: ProductImage(product: item.product, size: 36),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.product.name,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  'Rs ${item.total.toStringAsFixed(0)}',
                  style: const TextStyle(
                    fontSize: 11,
                    color: Color(0xFF00A78E),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          _buildQtyControls(compact: true),
          const SizedBox(width: 4),
          GestureDetector(
            onTap: () => cartNotifier.removeProduct(item.product),
            child: const Icon(Icons.close, size: 14, color: Colors.grey),
          ),
        ],
      ),
    );
  }

  Widget _buildNormal(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFF007AFF).withValues(alpha: 0.2),
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
                      'SKU: ${item.product.sku ?? "N/A"}',
                      style:
                          const TextStyle(fontSize: 10, color: Colors.grey),
                    ),
                    if (item.product.gstRate != null)
                      Text(
                        'GST: ${item.product.gstRate} (${item.product.gstType})',
                        style: const TextStyle(
                            fontSize: 10, color: Colors.grey),
                      ),
                  ],
                ),
              ),
              _buildQtyControls(),
              const SizedBox(width: 8),
              _buildDiscountBadge(),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: () => cartNotifier.removeProduct(item.product),
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child:
                      const Icon(Icons.close, size: 14, color: Colors.grey),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _detailCol(
                  'Item Rate', 'Rs ${item.product.price.toStringAsFixed(2)}'),
              _detailCol('Amount', 'Rs ${item.subtotal.toStringAsFixed(2)}'),
              _detailCol('Total', 'Rs ${item.total.toStringAsFixed(2)}',
                  isBold: true),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildQtyControls({bool compact = false}) {
    final iconSize = compact ? 12.0 : 14.0;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _circleBtn(
          Icons.remove,
          () => cartNotifier.updateQuantity(item.product, item.quantity - 1),
          iconSize,
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6),
          child: Text(
            '${item.quantity}',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: compact ? 12 : 14,
            ),
          ),
        ),
        _circleBtn(
          Icons.add,
          () => cartNotifier.updateQuantity(item.product, item.quantity + 1),
          iconSize,
        ),
      ],
    );
  }

  Widget _circleBtn(IconData icon, VoidCallback onTap, double size) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(2),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade300),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, size: size),
      ),
    );
  }

  Widget _buildDiscountBadge() {
    final hasDiscount = item.manualDiscount > 0;
    return GestureDetector(
      onTap: () => onShowDiscount(item),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          border: Border.all(
            color: hasDiscount ? Colors.red.shade300 : Colors.grey.shade200,
          ),
          borderRadius: BorderRadius.circular(4),
          color: hasDiscount ? Colors.red.shade50 : null,
        ),
        child: Text(
          hasDiscount
              ? '-${item.isPercentDiscount ? '${item.manualDiscount.toInt()}%' : 'Rs ${item.manualDiscount.toInt()}'}'
              : 'Discount',
          style: TextStyle(
            fontSize: 11,
            color: hasDiscount ? Colors.red : Colors.black,
          ),
        ),
      ),
    );
  }

  Widget _detailCol(String label, String value, {bool isBold = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(fontSize: 12, color: Colors.grey)),
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
