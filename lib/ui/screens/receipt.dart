import 'package:flutter/material.dart';
import '../../core/l10n.dart';
import '../../core/money.dart';

/// Paper-style receipt preview for an order. Display only; printing and
/// sharing are intentionally out of scope for this version.
Future<void> showReceiptDialog(
  BuildContext context, {
  required String lang,
  required Map<String, dynamic> order,
  required List<Map<String, dynamic>> items,
  required List<Map<String, dynamic>> payments,
  required Map<String, dynamic>? biz,
  required String code,
  required String symbol,
}) {
  String tr(String k) => L.t(lang, k);
  final confirmed = payments.where((p) => p['status'] == 'confirmed').toList();
  final paid = confirmed.fold<int>(0, (s, p) => s + (p['amount_minor'] as int));
  final total = order['total_minor'] as int;
  final change = calcChange(paid: paid, total: total);
  final created = DateTime.tryParse(
    order['created_at'] as String? ?? '',
  )?.toLocal();
  final dateStr = created == null
      ? ''
      : '${created.day.toString().padLeft(2, '0')}/${created.month.toString().padLeft(2, '0')}/${created.year} '
            '${created.hour.toString().padLeft(2, '0')}:${created.minute.toString().padLeft(2, '0')}';
  final mono = const TextStyle(fontFamily: 'monospace', fontSize: 13);

  Widget line(String left, String right, {bool bold = false}) {
    final style = mono.copyWith(
      fontWeight: bold ? FontWeight.w800 : FontWeight.w400,
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Expanded(child: Text(left, style: style)),
          Text(right, style: style),
        ],
      ),
    );
  }

  return showDialog(
    context: context,
    builder: (ctx) => Dialog(
      insetPadding: const EdgeInsets.all(20),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 360),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                (biz?['name'] as String? ?? 'RanPOS').toUpperCase(),
                textAlign: TextAlign.center,
                style: mono.copyWith(fontWeight: FontWeight.w800, fontSize: 16),
              ),
              if ((biz?['address'] as String? ?? '').isNotEmpty)
                Text(
                  biz!['address'] as String,
                  textAlign: TextAlign.center,
                  style: mono.copyWith(fontSize: 12, color: Colors.black54),
                ),
              if ((biz?['phone'] as String? ?? '').isNotEmpty)
                Text(
                  biz!['phone'] as String,
                  textAlign: TextAlign.center,
                  style: mono.copyWith(fontSize: 12, color: Colors.black54),
                ),
              const SizedBox(height: 8),
              const _DashedLine(),
              const SizedBox(height: 8),
              line(order['display_number'] as String, dateStr),
              line(
                tr('receipt'),
                (order['order_type'] as String) == 'dine_in'
                    ? tr('dineIn')
                    : tr('takeaway'),
              ),
              const SizedBox(height: 8),
              const _DashedLine(),
              const SizedBox(height: 8),
              for (final it in items)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(it['item_name'] as String, style: mono),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              '  ${it['quantity']} x ${formatMoney(it['price_minor'] as int, code, symbol)}',
                              style: mono.copyWith(color: Colors.black54),
                            ),
                          ),
                          Text(
                            formatMoney(
                              (it['price_minor'] as int) *
                                  (it['quantity'] as int),
                              code,
                              symbol,
                            ),
                            style: mono,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 8),
              const _DashedLine(),
              const SizedBox(height: 8),
              line(
                tr('subtotal'),
                formatMoney(order['subtotal_minor'] as int, code, symbol),
              ),
              line(
                tr('tax'),
                formatMoney(order['tax_minor'] as int, code, symbol),
              ),
              line(tr('total'), formatMoney(total, code, symbol), bold: true),
              const SizedBox(height: 8),
              const _DashedLine(),
              const SizedBox(height: 8),
              for (final p in confirmed)
                line(
                  '${tr('paymentMethod')}: ${(p['method'] as String) == 'cash' ? tr('cash') : tr('card')}',
                  formatMoney(p['amount_minor'] as int, code, symbol),
                ),
              if (change > 0)
                line(tr('change'), formatMoney(change, code, symbol)),
              if (confirmed.isEmpty) line(tr('paymentStatus'), tr('unpaid')),
              const SizedBox(height: 8),
              const _DashedLine(),
              const SizedBox(height: 12),
              Text(
                tr('thankYou'),
                textAlign: TextAlign.center,
                style: mono.copyWith(fontSize: 12),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: Text(tr('cancel')),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class _DashedLine extends StatelessWidget {
  const _DashedLine();
  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final count = (constraints.maxWidth / 10).floor().clamp(1, 60);
        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: List.generate(
            count,
            (_) => const SizedBox(
              width: 5,
              height: 1,
              child: DecoratedBox(
                decoration: BoxDecoration(color: Colors.black26),
              ),
            ),
          ),
        );
      },
    );
  }
}
