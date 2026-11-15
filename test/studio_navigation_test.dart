import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:subtitle_studio_ai/main.dart';

void main() {
  testWidgets('Studio navigation opens a real subtitle editor', (tester) async {
    await tester.pumpWidget(const StudioApp());

    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.text('Projekt i ri'), findsOneWidget);
    await tester.tap(find.text('Projekt i ri'));
    await tester.pumpAndSettle();

    expect(find.byType(SubtitlePreviewPage), findsOneWidget);
  });

  testWidgets('Premium navigation exposes four distinct destinations', (tester) async {
    await tester.pumpWidget(const StudioApp());
    final bar = tester.widget<NavigationBar>(find.byType(NavigationBar));
    expect(bar.destinations.length, 4);
    expect(bar.destinations.map((item) => (item as NavigationDestination).label).toList(),
        ['Ballina', 'Studio', 'AI', 'Projektet']);
  });
}
