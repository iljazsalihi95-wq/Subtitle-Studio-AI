import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:subtitle_studio_ai/main.dart';

void main() {
  testWidgets('Premium studio theme keeps its original navy and gold palette', (tester) async {
    await tester.pumpWidget(const StudioApp());
    final theme = Theme.of(tester.element(find.byType(Scaffold).first));
    expect(theme.brightness, Brightness.dark);
    expect(theme.scaffoldBackgroundColor, const Color(0xFF07111F));
    expect(theme.appBarTheme.foregroundColor, const Color(0xFFE8C170));
    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
