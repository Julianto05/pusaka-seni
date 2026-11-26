import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pusaka_seni_v2/main.dart';

void main() {
  testWidgets('PusakaSeniApp configures scoringUrl properly and initializes',
      (WidgetTester tester) async {
    expect(PusakaSeniApp.scoringUrl,
        'https://beseni-temp.pusakarinjani.my.id');

    await tester.pumpWidget(
      const PusakaSeniApp(
        home: Scaffold(
          body: Text('Portal Scoring Seni Ready'),
        ),
      ),
    );

    expect(find.byType(PusakaSeniApp), findsOneWidget);
    expect(find.text('Portal Scoring Seni Ready'), findsOneWidget);
  });
}
