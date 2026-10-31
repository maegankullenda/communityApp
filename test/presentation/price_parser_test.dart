import 'package:flutter_test/flutter_test.dart';

import 'package:community_app/presentation/price_parser.dart';

void main() {
  test('whole and decimal prices become cents', () {
    expect(parsePriceToCents('85'), 8500);
    expect(parsePriceToCents('85.5'), 8550);
    expect(parsePriceToCents('85.50'), 8550);
    expect(parsePriceToCents('0.5'), 50);
    expect(parsePriceToCents(' 12 '), 1200);
  });

  test('unusable prices are rejected', () {
    expect(parsePriceToCents(''), isNull);
    expect(parsePriceToCents('85.555'), isNull);
    expect(parsePriceToCents('-1'), isNull);
    expect(parsePriceToCents('12.5.0'), isNull);
    expect(parsePriceToCents('free'), isNull);
  });
}
