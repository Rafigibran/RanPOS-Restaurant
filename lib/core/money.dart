// Money is always stored as an integer in the smallest unit.
// USD/EUR: cents. IDR/JPY: whole rupiah/yen (zero-decimal currencies).
// No floating point is used for totals, so rounding is explicit.

/// Currencies the user can pick, with their display symbols.
/// Changing currency only changes how amounts are displayed; amounts are
/// stored in the currency's minor unit, so the currency should be set
/// before menu prices are entered.
const Map<String, String> currencySymbols = {
  'USD': '\$',
  'IDR': 'Rp',
  'EUR': '€',
  'JPY': '¥',
  'MYR': 'RM',
  'SGD': 'S\$',
  'GBP': '£',
  'AUD': 'A\$',
  'PHP': '₱',
  'THB': '฿',
  'VND': '₫',
  'INR': '₹',
  'KRW': '₩',
  'CNY': '¥',
};

bool isZeroDecimal(String code) =>
    const {'IDR', 'JPY', 'KRW', 'VND'}.contains(code.toUpperCase());

String formatMoney(int minor, String code, String symbol) {
  final negative = minor < 0;
  final abs = minor.abs();
  if (isZeroDecimal(code)) {
    return '${negative ? '-' : ''}$symbol${_thousands(abs)}';
  }
  final whole = abs ~/ 100;
  final cents = abs % 100;
  return '${negative ? '-' : ''}$symbol${_thousands(whole)}.${cents.toString().padLeft(2, '0')}';
}

String _thousands(int n) {
  final s = n.toString();
  final out = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) out.write(',');
    out.write(s[i]);
  }
  return out.toString();
}

/// Returns (subtotal, tax, total) in minor units.
({int subtotal, int tax, int total}) calcTotals({
  required List<({int price, int qty, int discount})> lines,
  required int taxPercent,
  required bool taxInclusive,
}) {
  var subtotal = 0;
  for (final l in lines) {
    subtotal += (l.price * l.qty) - l.discount;
  }
  if (subtotal < 0) subtotal = 0;
  if (taxInclusive) {
    // Tax is already inside the price: extract it for display only.
    final tax = (subtotal * taxPercent) ~/ (100 + taxPercent);
    return (subtotal: subtotal, tax: tax, total: subtotal);
  }
  final tax = (subtotal * taxPercent + 50) ~/ 100;
  return (subtotal: subtotal, tax: tax, total: subtotal + tax);
}

int calcChange({required int paid, required int total}) =>
    paid > total ? paid - total : 0;

/// Order display numbers: RAN-20261029-0001 style, date + sequence.
String orderDisplayNumber(DateTime now, int sequence) {
  final d =
      '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}';
  return 'RAN-$d-${sequence.toString().padLeft(4, '0')}';
}
