import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:video_download/main.dart';

void main() {
  testWidgets('home screen renders parser flow', (WidgetTester tester) async {
    await tester.pumpWidget(const MyApp());

    expect(find.text('Tube Fetch'), findsOneWidget);
    expect(find.textContaining('粘贴视频链接'), findsOneWidget);
    expect(find.text('解析视频'), findsNWidgets(2));
    expect(find.byType(TextField), findsOneWidget);
  });
}
