import 'package:flutter_test/flutter_test.dart';
import 'package:subtitle_studio_ai/features/subtitles/srt_editor.dart';

void main() {
  test('retimes a passage proportionally and preserves both languages', () {
    const cue = SubtitleCue(
      start: Duration(seconds: 10),
      end: Duration(seconds: 12),
      original: 'Përshëndetje',
      translation: 'Hallo',
    );
    final result = retimeSubtitlePassage(
      [cue],
      sourceStart: const Duration(seconds: 10),
      sourceEnd: const Duration(seconds: 20),
      targetStart: const Duration(seconds: 30),
      targetEnd: const Duration(seconds: 50),
    );
    expect(result.single.start, const Duration(seconds: 30));
    expect(result.single.end, const Duration(seconds: 34));
    expect(result.single.original, 'Përshëndetje');
    expect(result.single.translation, 'Hallo');
  });

  test('leaves unrelated subtitles untouched', () {
    const cue = SubtitleCue(
      start: Duration(seconds: 1),
      end: Duration(seconds: 2),
      original: 'Intro',
    );
    final result = retimeSubtitlePassage(
      [cue],
      sourceStart: const Duration(seconds: 10),
      sourceEnd: const Duration(seconds: 20),
      targetStart: const Duration(seconds: 12),
      targetEnd: const Duration(seconds: 24),
    );
    expect(identical(result.single, cue), isTrue);
  });

  test('rejects a subtitle crossing the selected passage', () {
    const cue = SubtitleCue(
      start: Duration(seconds: 9),
      end: Duration(seconds: 12),
      original: 'Crossing',
    );
    expect(
      () => retimeSubtitlePassage(
        [cue],
        sourceStart: const Duration(seconds: 10),
        sourceEnd: const Duration(seconds: 20),
        targetStart: const Duration(seconds: 12),
        targetEnd: const Duration(seconds: 22),
      ),
      throwsFormatException,
    );
  });
}
