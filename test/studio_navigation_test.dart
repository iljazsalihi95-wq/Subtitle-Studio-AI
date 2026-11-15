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
    expect(find.byIcon(Icons.home_outlined), findsOneWidget);
    expect(find.byIcon(Icons.subtitles_outlined), findsOneWidget);
    expect(find.byIcon(Icons.auto_awesome_outlined), findsOneWidget);
    expect(find.byIcon(Icons.folder_outlined), findsOneWidget);
  });
}
