import 'package:flutter/material.dart';
import 'package:ezo/features/pos/state/cart_state.dart';

/// Reusable totals display for POS layouts.
/// Set [compact] for narrower panels.
class PosTotalsDisplay extends StatelessWidget {
  final CartState cartState;
  final bool compact;
  final VoidCallback? onCheckout;
  final VoidCallback? onPrint;

  const PosTotalsDisplay({
    super.key,
    required this.cartState,
    this.compact = false,
    this.onCheckout,
    this.onPrint,
  });

  @override
  Widget build(BuildContext context) {
    final fontSize = compact ? 13.0 : 16.0;
    final totalFontSize = compact ? 16.0 : 20.0;

    return Container(
      padding: EdgeInsets.all(compact ? 12 : 16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Colors.grey.shade200)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (!compact)
            const Padding(
              padding: EdgeInsets.only(bottom: 8),
              child: Text(
                'Payment Summary',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
              ),
            ),
          _row('Sub Total', 'Rs ${cartState.subtotal.toStringAsFixed(2)}',
              fontSize: fontSize),
          _row('GST', 'Rs ${cartState.taxAmount.toStringAsFixed(2)}',
              fontSize: fontSize),
          if (cartState.totalDiscount > 0)
            _row(
              'Discount',
              '-Rs ${cartState.totalDiscount.toStringAsFixed(2)}',
              fontSize: fontSize,
              isRed: true,
            ),
          Divider(height: compact ? 12 : 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                compact ? 'Total' : 'Amount to be Paid',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: totalFontSize,
                ),
              ),
              Text(
                'Rs ${cartState.total.toInt()}',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: totalFontSize,
                ),
              ),
            ],
          ),
          if (onCheckout != null) ...[
            SizedBox(height: compact ? 8 : 16),
            SizedBox(
              width: double.infinity,
              height: compact ? 40 : 50,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF007AFF),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                onPressed:
                    cartState.items.isEmpty ? null : onCheckout,
                child: Text(
                  'Checkout',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: compact ? 14 : 16,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _row(String label, String value,
      {bool isRed = false, double fontSize = 16}) {
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
              fontSize: fontSize,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              color: isRed ? Colors.red : Colors.grey.shade600,
              fontWeight: FontWeight.w500,
              fontSize: fontSize,
            ),
          ),
        ],
      ),
    );
  }
}
