import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sanjay_roadlines_fleet/main.dart';

void main() {
  testWidgets('App smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const SanjayRoadlinesApp());

    expect(find.byIcon(Icons.local_shipping), findsOneWidget);
  });
}
