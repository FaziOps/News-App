import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:news_app/main.dart';

void main() {
  testWidgets('Counter increments smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const NewsApp());

    // Verify that the welcome text is present.
    expect(find.textContaining('Welcome', findRichText: true), findsOneWidget);
  });

  testWidgets('Real-time search text field test', (WidgetTester tester) async {
    // Build our app
    await tester.pumpWidget(const NewsApp());

    // Tap Continue to get to HomeScreen
    await tester.tap(find.text('Continue'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    // Tap the Search icon in bottom nav bar
    await tester.tap(find.byIcon(Icons.search));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    // Verify search page is showing placeholder instructions
    expect(find.text('Explore Global Headlines'), findsOneWidget);

    // Enter search query
    await tester.enterText(find.byType(TextField), 'Trump');
    await tester.pump();
    
    // Wait for the 300ms debounce timer to fire
    await tester.pump(const Duration(milliseconds: 350));

    // Verify that results showing articles with 'Trump' are present
    expect(find.textContaining('Trump', findRichText: true), findsWidgets);
  });
}

