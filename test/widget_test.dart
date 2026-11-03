import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:subtitle_studio_ai/features/subtitles/srt_editor.dart';
import 'package:subtitle_studio_ai/main.dart';

void main() {
  testWidgets('Home exposes the functional subtitle studio entry', (tester) async {
    await tester.pumpWidget(const StudioApp());
    expect(find.byType(HomePage), findsOneWidget);
    expect(find.text('Projekt i ri'), findsOneWidget);
    expect(find.text('Studio e titrave'), findsOneWidget);
    expect(find.text('Hap SRT/VTT • timeline • editor'), findsOneWidget);
    expect(find.text('Skedarët lokalë • pa API keys në APK'), findsOneWidget);
  });

  testWidgets('Subtitle editor shows timeline overlap warning', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: SubtitlePreviewPage(filename: 'test.srt', cues: [
      SubtitleCue(start: Duration(seconds: 1), end: Duration(seconds: 4), original: 'Një'),
      SubtitleCue(start: Duration(seconds: 3), end: Duration(seconds: 5), original: 'Dy'),
    ])));
    await tester.pumpAndSettle();
    expect(find.textContaining('1 mbivendosje'), findsOneWidget);
    expect(find.text('Mbivendosje kohe'), findsOneWidget);
  });
}
