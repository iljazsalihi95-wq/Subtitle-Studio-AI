import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:subtitle_studio_ai/features/subtitles/srt_editor.dart';
import 'package:subtitle_studio_ai/main.dart';

void main() {
  testWidgets('Home exposes the functional subtitle studio entry', (tester) async {
    await tester.pumpWidget(const StudioApp());
    await tester.pump();

    expect(find.text('SUBTITLE STUDIO AI'), findsOneWidget);
    expect(find.text('Projekt i ri'), findsOneWidget);
    expect(find.text('Studio e titrave'), findsOneWidget);
  });

  testWidgets('Subtitle editor shows timeline overlap warning', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: SubtitlePreviewPage(
        filename: 'test.srt',
        cues: [
          SubtitleCue(
            start: Duration(seconds: 1),
            end: Duration(seconds: 4),
            original: 'Një',
          ),
          SubtitleCue(
            start: Duration(seconds: 3),
            end: Duration(seconds: 5),
            original: 'Dy',
          ),
        ],
      ),
    ));
    await tester.pump();

    expect(find.textContaining('1 mbivendosje'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Mbivendosje kohe'), 250, scrollable: find.byType(Scrollable).first);
    expect(find.text('Mbivendosje kohe'), findsWidgets);
  });
}
