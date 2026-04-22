import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:video_download/main.dart';

void main() {
  testWidgets('home screen renders parser flow', (WidgetTester tester) async {
    tester.binding.platformDispatcher.localeTestValue = const Locale('en');
    addTearDown(tester.binding.platformDispatcher.clearLocaleTestValue);

    await tester.pumpWidget(const MyApp());

    expect(find.text('Tube Fetch'), findsOneWidget);
    expect(find.textContaining('Paste a video link'), findsOneWidget);
    expect(find.text('Parse Video'), findsNWidgets(2));
    expect(find.byType(TextField), findsOneWidget);
  });
}
