import 'package:flutter_test/flutter_test.dart';
import 'package:subtitle_studio_ai/features/subtitles/srt_editor.dart';

void main() {
  test('imports WebVTT short MM:SS.mmm timecodes', () {
    const source = 'WEBVTT\n\n00:01.250 --> 00:04.500\nPërshëndetje';
    final cues = parseSubtitles(source);
    expect(cues, hasLength(1));
    expect(cues.single.start.inMilliseconds, 1250);
    expect(cues.single.end.inMilliseconds, 4500);
    expect(cues.single.original, 'Përshëndetje');
  });

  test('keeps long HH:MM:SS.mmm WebVTT timecodes', () {
    final cues = parseSubtitles('WEBVTT\n\n01:02:03.400 --> 01:02:04.500\nTekst');
    expect(cues.single.start.inMilliseconds, 3723400);
  });

  test('round-trips WebVTT after the first hour without losing timing', () {
    const source = 'WEBVTT\n\n61:02.125 --> 61:05.750\nVargu i parë';
    final imported = parseSubtitles(source);
    expect(imported.single.start.inMilliseconds, 3662125);
    final exported = exportVtt(imported);
    final restored = parseSubtitles(exported);
    expect(restored.single.start, imported.single.start);
    expect(restored.single.end, imported.single.end);
    expect(restored.single.original, imported.single.original);
  });

  test('rejects invalid short timestamp seconds', () {
    expect(() => parseSubtitles('WEBVTT\n\n00:61.000 --> 00:62.000\nGabim'), throwsFormatException);
  });
}
