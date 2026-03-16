import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ezo/features/pos/providers/pos_layout_provider.dart';

/// Popup menu to switch POS layouts.
/// Place this in the POS screen toolbar.
class PosLayoutSelector extends ConsumerWidget {
  const PosLayoutSelector({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final current = ref.watch(posLayoutProvider);

    return PopupMenuButton<PosLayoutType>(
      tooltip: 'Switch Layout',
      offset: const Offset(0, 48),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      icon: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: const Color(0xFF007AFF).withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: const Color(0xFF007AFF).withValues(alpha: 0.3),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(current.icon, size: 16, color: const Color(0xFF007AFF)),
            const SizedBox(width: 6),
            Text(
              current.displayName,
              style: const TextStyle(
                color: Color(0xFF007AFF),
                fontWeight: FontWeight.w600,
                fontSize: 12,
              ),
            ),
            const SizedBox(width: 4),
            const Icon(Icons.keyboard_arrow_down,
                size: 16, color: Color(0xFF007AFF)),
          ],
        ),
      ),
      onSelected: (layout) {
        ref.read(posLayoutProvider.notifier).setLayout(layout);
      },
      itemBuilder: (context) => PosLayoutType.values.map((layout) {
        final isSelected = layout == current;
        return PopupMenuItem<PosLayoutType>(
          value: layout,
          child: Row(
            children: [
              Icon(
                layout.icon,
                size: 20,
                color:
                    isSelected ? const Color(0xFF007AFF) : Colors.grey.shade600,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      layout.displayName,
                      style: TextStyle(
                        fontWeight:
                            isSelected ? FontWeight.bold : FontWeight.w500,
                        color: isSelected
                            ? const Color(0xFF007AFF)
                            : Colors.black87,
                        fontSize: 14,
                      ),
                    ),
                    Text(
                      layout.description,
                      style: TextStyle(
                          fontSize: 11, color: Colors.grey.shade500),
                    ),
                  ],
                ),
              ),
              if (isSelected)
                const Icon(Icons.check_circle,
                    size: 18, color: Color(0xFF007AFF)),
            ],
          ),
        );
      }).toList(),
    );
  }
}
