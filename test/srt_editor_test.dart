import 'package:flutter_test/flutter_test.dart';
import 'package:subtitle_studio_ai/features/subtitles/srt_editor.dart';
void main() {
  test('Translation keeps original timecodes', () {
    final cue = SubtitleCue(start: const Duration(seconds: 1), end: const Duration(milliseconds: 3500), original: 'Merhaba').translated('Përshëndetje');
    expect(exportSrt([cue]), contains('00:00:01,000 --> 00:00:03,500'));
    expect(exportSrt([cue]), contains('Përshëndetje'));
    expect(exportSrt([cue], translated: false), contains('Merhaba'));
  });
  test('SRT import preserves cue timing and multiline text', () {
    final cues = parseSubtitles('1\n00:00:01,000 --> 00:00:03,500\nHello\nworld');
    expect(cues, hasLength(1));
    expect(cues.single.original, 'Hello\nworld');
    expect(cues.single.end.inMilliseconds, 3500);
  });
  test('WebVTT import accepts dot timestamps', () {
    final cues = parseSubtitles('WEBVTT\n\n00:00:02.000 --> 00:00:04.200\nWelcome');
    expect(cues.single.start.inSeconds, 2);
    expect(cues.single.original, 'Welcome');
  });
  test('WebVTT header with metadata preserves the first cue', () {
    final cues = parseSubtitles('WEBVTT - Pilot\\nKind: captions\\n\\n00:00:01.000 --> 00:00:02.500\\nFirst cue\\n\\n00:00:03.000 --> 00:00:04.000\\nSecond cue');
    expect(cues, hasLength(2));
    expect(cues.first.original, 'First cue');
    expect(cues.last.original, 'Second cue');
  });
  test('Untranslated cues export original text instead of blank subtitles', () {
    final cue = SubtitleCue(start: const Duration(seconds: 1), end: const Duration(seconds: 2), original: 'Original');
    expect(exportSrt([cue]), contains('Original'));
    expect(exportVtt([cue]), contains('Original'));
  });
  test('Rejects reversed timestamps', () {
    expect(() => parseSubtitles('1\n00:00:04,000 --> 00:00:02,000\nBad'), throwsFormatException);
  });
  test('Timeline validation identifies overlaps and empty cues', () {
    final report = validateTimeline(const [
      SubtitleCue(start: Duration(seconds: 1), end: Duration(seconds: 4), original: 'One'),
      SubtitleCue(start: Duration(seconds: 3), end: Duration(seconds: 5), original: 'Two'),
      SubtitleCue(start: Duration(seconds: 6), end: Duration(seconds: 7), original: '   '),
    ]);
    expect(report.overlapIndexes, [1]);
    expect(report.emptyIndexes, [2]);
    expect(report.isClean, isFalse);
  });
}
