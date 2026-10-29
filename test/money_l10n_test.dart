import 'package:flutter_test/flutter_test.dart';
import 'package:ranpos/core/l10n.dart';
import 'package:ranpos/core/money.dart';
import 'package:ranpos/data/repository.dart';

void main() {
  test('tax exclusive totals', () {
    final t = calcTotals(
      lines: [(price: 1699, qty: 1, discount: 0)],
      taxPercent: 5,
      taxInclusive: false,
    );
    expect(t.subtotal, 1699);
    expect(t.tax, 85);
    expect(t.total, 1784);
  });

  test('tax inclusive extracts tax without changing total', () {
    final t = calcTotals(
      lines: [(price: 1050, qty: 1, discount: 0)],
      taxPercent: 5,
      taxInclusive: true,
    );
    expect(t.total, 1050);
    expect(t.tax, 50);
  });

  test('money formatting USD and IDR', () {
    expect(formatMoney(1699, 'USD', '\$'), '\$16.99');
    expect(formatMoney(17000, 'IDR', 'Rp'), 'Rp17,000');
  });

  test('change is never negative', () {
    expect(calcChange(paid: 1000, total: 1500), 0);
    expect(calcChange(paid: 2000, total: 1500), 500);
  });

  test('order display number format', () {
    expect(orderDisplayNumber(DateTime(2026, 10, 29), 3), 'RAN-20261029-0003');
  });

  test('locale mapping and fallback', () {
    expect(L.resolve('id-ID', 'system'), 'id');
    expect(L.resolve('ar-SA', 'system'), 'ar');
    expect(L.resolve('fr-FR', 'system'), 'en');
    expect(L.resolve('en-US', 'es'), 'es');
    expect(L.t('id', 'home'), 'Beranda');
    expect(L.t('ar', 'home'), 'الرئيسية');
  });

  test('backup validation rejects wrong format and future version', () {
    expect(validateBackup({'format': 'other'}), isFalse);
    expect(
      validateBackup({
        'format': 'ranpos-backup',
        'backup_schema_version': 99,
        'data': {'orders': [], 'menu_items': []},
      }),
      isFalse,
    );
    expect(
      validateBackup({
        'format': 'ranpos-backup',
        'backup_schema_version': 1,
        'data': {'orders': [], 'menu_items': []},
      }),
      isTrue,
    );
  });
}
