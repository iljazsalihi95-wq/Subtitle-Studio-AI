import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:subtitle_studio_ai/main.dart';

void main() {
  testWidgets('Studio keeps premium dark theme and accessible gold controls', (tester) async {
    await tester.pumpWidget(const StudioApp());

    expect(find.byType(HomePage), findsOneWidget);
    final context = tester.element(find.byType(HomePage));
    final theme = Theme.of(context);
    expect(theme.brightness, Brightness.dark);
    expect(theme.scaffoldBackgroundColor, const Color(0xFF07111F));
    expect(theme.appBarTheme.foregroundColor, const Color(0xFFE8C170));
    expect(theme.snackBarTheme.behavior, SnackBarBehavior.floating);
    expect(theme.snackBarTheme.actionTextColor, const Color(0xFFE8C170));
    expect(theme.elevatedButtonTheme.style?.minimumSize?.resolve({}), const Size(48, 48));
  });
}
