import 'package:flutter_test/flutter_test.dart';
import 'package:subtitle_studio_ai/features/subtitles/srt_editor.dart';

void main() {
  test('SRT and WebVTT preserve original text when translation is empty', () {
    final cues = [
      const SubtitleCue(
        start: Duration(minutes: 61, seconds: 2, milliseconds: 125),
        end: Duration(minutes: 61, seconds: 4, milliseconds: 875),
        original: 'Rreshti i parë\nRreshti i dytë',
      ),
    ];
    for (final exported in [exportSrt(cues), exportVtt(cues)]) {
      final imported = parseSubtitles(exported);
      expect(imported, hasLength(1));
      expect(imported.single.original, cues.single.original);
      expect(imported.single.start, cues.single.start);
      expect(imported.single.end, cues.single.end);
    }
  });

  test('WebVTT accepts elapsed minutes beyond one hour', () {
    final cues = parseSubtitles('WEBVTT\n\n61:02.125 --> 61:04.875\nTeksti');
    expect(cues.single.start, const Duration(minutes: 61, seconds: 2, milliseconds: 125));
  });

  test('Export refuses intervals lost to millisecond rounding', () {
    final cues = [
      const SubtitleCue(
        start: Duration(microseconds: 1100),
        end: Duration(microseconds: 1900),
        original: 'Teksti',
      ),
    ];
    expect(() => exportSrt(cues), throwsFormatException);
    expect(() => exportVtt(cues), throwsFormatException);
  });
}
