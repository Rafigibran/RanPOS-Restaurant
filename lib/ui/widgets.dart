import 'package:flutter/material.dart';
import '../core/l10n.dart';
import '../core/money.dart';
import 'theme.dart';

class RanCard extends StatelessWidget {
  final Widget child;
  final EdgeInsets padding;
  final VoidCallback? onTap;
  const RanCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.onTap,
  });
  @override
  Widget build(BuildContext context) {
    return Card(
      color: Colors.white,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: const BorderSide(color: Color(0xFFEEEEEE)),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Padding(padding: padding, child: child),
      ),
    );
  }
}

class StatusChip extends StatelessWidget {
  final String label;
  final Color color;
  final IconData icon;
  const StatusChip({
    super.key,
    required this.label,
    required this.color,
    required this.icon,
  });
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

Color orderStatusColor(String s) {
  switch (s) {
    case 'ready':
      return RanTheme.green;
    case 'completed':
      return RanTheme.blue;
    case 'cancelled':
      return Colors.red;
    default:
      return RanTheme.amber;
  }
}

IconData orderStatusIcon(String s) {
  switch (s) {
    case 'ready':
      return Icons.check_circle;
    case 'completed':
      return Icons.done_all;
    case 'cancelled':
      return Icons.cancel;
    default:
      return Icons.soup_kitchen;
  }
}

String orderStatusKey(String s) {
  switch (s) {
    case 'in_progress':
      return 'inProgress';
    case 'ready':
      return 'ready';
    case 'completed':
      return 'completed';
    default:
      return 'cancelled';
  }
}

Color paymentStatusColor(String s) {
  switch (s) {
    case 'paid':
      return RanTheme.green;
    case 'refunded':
      return Colors.red;
    default:
      return RanTheme.amber;
  }
}

String paymentStatusKey(String s) {
  switch (s) {
    case 'paid':
      return 'paid';
    case 'partially_paid':
      return 'partiallyPaid';
    case 'refunded':
      return 'refunded';
    default:
      return 'unpaid';
  }
}

/// Shows the order status chip and the payment status chip together.
/// A cancelled order always shows its cancelled status, never a payment
/// status that would hide it.
class OrderStatusChips extends StatelessWidget {
  final String lang;
  final Map<String, dynamic> order;
  final WrapAlignment alignment;
  const OrderStatusChips({
    super.key,
    required this.lang,
    required this.order,
    this.alignment = WrapAlignment.end,
  });
  @override
  Widget build(BuildContext context) {
    final orderStatus = order['order_status'] as String? ?? 'in_progress';
    final paymentStatus = order['payment_status'] as String? ?? 'unpaid';
    return Wrap(
      alignment: alignment,
      spacing: 6,
      runSpacing: 6,
      children: [
        StatusChip(
          label: L.t(lang, orderStatusKey(orderStatus)),
          color: orderStatusColor(orderStatus),
          icon: orderStatusIcon(orderStatus),
        ),
        StatusChip(
          label: L.t(lang, paymentStatusKey(paymentStatus)),
          color: paymentStatusColor(paymentStatus),
          icon: Icons.payment,
        ),
      ],
    );
  }
}

String initials(String name) {
  final parts = name.trim().split(RegExp(r'\s+'));
  if (parts.isEmpty) return '?';
  if (parts.length == 1) return parts.first.characters.first.toUpperCase();
  return (parts.first.characters.first + parts[1].characters.first)
      .toUpperCase();
}

class DishThumb extends StatelessWidget {
  final String name;
  final double size;
  const DishThumb({super.key, required this.name, this.size = 64});
  @override
  Widget build(BuildContext context) {
    final colors = [
      const Color(0xFFFFE8E0),
      const Color(0xFFFFF1D6),
      const Color(0xFFE4F3E8),
      const Color(0xFFE3ECFF),
    ];
    final idx = name.isEmpty ? 0 : name.codeUnitAt(0) % colors.length;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: colors[idx],
        borderRadius: BorderRadius.circular(14),
      ),
      child: const Icon(Icons.restaurant, color: RanTheme.accent, size: 28),
    );
  }
}

class MoneyText extends StatelessWidget {
  final int minor;
  final String code;
  final String symbol;
  final TextStyle? style;
  const MoneyText(
    this.minor, {
    super.key,
    required this.code,
    required this.symbol,
    this.style,
  });
  @override
  Widget build(BuildContext context) {
    return Text(
      formatMoney(minor, code, symbol),
      style:
          style ?? const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
    );
  }
}

class EmptyState extends StatelessWidget {
  final String title;
  final String hint;
  const EmptyState({super.key, required this.title, required this.hint});
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.inbox_outlined, size: 48, color: RanTheme.muted),
            const SizedBox(height: 12),
            Text(
              title,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            Text(
              hint,
              textAlign: TextAlign.center,
              style: const TextStyle(color: RanTheme.muted),
            ),
          ],
        ),
      ),
    );
  }
}
