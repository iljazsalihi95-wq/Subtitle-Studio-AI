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
  test('Cue text starting WEBVTT is not mistaken for a file signature', () {
    final cues = parseSubtitles('1\n00:00:01,000 --> 00:00:02,000\nWEBVTTIntro');
    expect(cues, hasLength(1));
    expect(cues.single.original, 'WEBVTTIntro');
  });
  test('WebVTT import accepts dot timestamps', () {
    final cues = parseSubtitles('WEBVTT\n\n00:00:02.000 --> 00:00:04.200\nWelcome');
    expect(cues.single.start.inSeconds, 2);
    expect(cues.single.original, 'Welcome');
  });
  test('WebVTT header with metadata preserves the first cue', () {
    final cues = parseSubtitles('WEBVTT - Pilot\nKind: captions\n\n00:00:01.000 --> 00:00:02.500\nFirst cue\n\n00:00:03.000 --> 00:00:04.000\nSecond cue');
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
  test('shift timing preserves text and translation', () {
    final cues = [SubtitleCue(start: const Duration(seconds: 2), end: const Duration(seconds: 4), original: 'Hello', translation: 'Përshëndetje')];
    final shifted = shiftSubtitleTiming(cues, const Duration(milliseconds: -500));
    expect(shifted.single.start, const Duration(milliseconds: 1500));
    expect(shifted.single.end, const Duration(milliseconds: 3500));
    expect(shifted.single.translation, 'Përshëndetje');
    expect(cues.single.start, const Duration(seconds: 2));
  });
  test('shift refuses negative timestamps', () {
    final cues = [SubtitleCue(start: const Duration(milliseconds: 100), end: const Duration(seconds: 2), original: 'Hi')];
    expect(() => shiftSubtitleTiming(cues, const Duration(milliseconds: -200)), throwsFormatException);
  });

  test('shift rejects reversed or zero-length cue intervals', () {
    final invalid = [
      SubtitleCue(start: const Duration(seconds: 4), end: const Duration(seconds: 3), original: 'Invalid'),
    ];
    expect(() => shiftSubtitleTiming(invalid, const Duration(seconds: 2)), throwsFormatException);
    final zeroLength = [
      SubtitleCue(start: const Duration(seconds: 2), end: const Duration(seconds: 2), original: 'Invalid'),
    ];
    expect(() => shiftSubtitleTiming(zeroLength, Duration.zero), throwsFormatException);
  });

  test('UTF-8 BOM and Windows newlines preserve first SRT cue', () {
    final cues = parseSubtitles('\uFEFF1\r\n00:00:01,000 --> 00:00:02,000\r\nPërshëndetje');
    expect(cues, hasLength(1));
    expect(cues.single.original, 'Përshëndetje');
    expect(cues.single.start.inMilliseconds, 1000);
  });
  test('Rejects timestamps with impossible seconds', () {
    expect(() => parseSubtitles('1\n00:00:61,000 --> 00:01:02,000\nBad'), throwsFormatException);
  });

  test('Nested subtitle overlaps are detected even across a shorter cue', () {
    final report = validateTimeline(const [
      SubtitleCue(start: Duration(seconds: 0), end: Duration(seconds: 20), original: 'Long'),
      SubtitleCue(start: Duration(seconds: 2), end: Duration(seconds: 3), original: 'Short'),
      SubtitleCue(start: Duration(seconds: 8), end: Duration(seconds: 9), original: 'Still overlapping long'),
      SubtitleCue(start: Duration(seconds: 21), end: Duration(seconds: 22), original: 'Clear'),
    ]);
    expect(report.overlapIndexes, [1, 2]);
  });
  test('Unsorted subtitle overlaps return original editor indexes', () {
    final report = validateTimeline(const [
      SubtitleCue(start: Duration(seconds: 10), end: Duration(seconds: 12), original: 'Later'),
      SubtitleCue(start: Duration(seconds: 1), end: Duration(seconds: 11), original: 'Earlier long'),
      SubtitleCue(start: Duration(seconds: 13), end: Duration(seconds: 14), original: 'Clear'),
    ]);
    expect(report.overlapIndexes, [0]);
    expect(report.emptyIndexes, isEmpty);
  });

  test('Playback lookup honors cue boundaries and gaps', () {
    const cues = [
      SubtitleCue(start: Duration(seconds: 1), end: Duration(seconds: 2), original: 'A'),
      SubtitleCue(start: Duration(seconds: 3), end: Duration(seconds: 4), original: 'B'),
    ];
    expect(cueAtPosition(cues, const Duration(seconds: 1))?.original, 'A');
    expect(cueAtPosition(cues, const Duration(seconds: 2)), isNull);
    expect(cueAtPosition(cues, const Duration(milliseconds: 3500))?.original, 'B');
    expect(cueAtPosition(cues, const Duration(seconds: -1)), isNull);
  });

  test('SRT and WebVTT exports refuse invalid subtitle intervals', () {
    const reversed = [SubtitleCue(start: Duration(seconds: 4), end: Duration(seconds: 2), original: 'Bad')];
    const negative = [SubtitleCue(start: Duration(seconds: -1), end: Duration(seconds: 1), original: 'Bad')];
    expect(() => exportSrt(reversed), throwsFormatException);
    expect(() => exportVtt(reversed), throwsFormatException);
    expect(() => exportSrt(negative), throwsFormatException);
    expect(() => exportVtt(negative), throwsFormatException);
  });


  test('Invalid intervals do not create false overlap warnings', () {
    const cues = [
      SubtitleCue(start: Duration(seconds: 1), end: Duration(seconds: 4), original: 'Valid'),
      SubtitleCue(start: Duration(seconds: 2), end: Duration(seconds: 1), original: 'Invalid'),
      SubtitleCue(start: Duration(seconds: 5), end: Duration(seconds: 6), original: 'Later'),
    ];
    final report = validateTimeline(cues);
    expect(report.emptyIndexes, [1]);
    expect(report.overlapIndexes, isEmpty);
  });

  test('Split refuses invalid and negative cue intervals', () {
    const negative = SubtitleCue(start: Duration(seconds: -1), end: Duration(seconds: 2), original: 'Bad');
    const reversed = SubtitleCue(start: Duration(seconds: 3), end: Duration(seconds: 1), original: 'Bad');
    expect(() => splitCue(negative, Duration.zero), throwsFormatException);
    expect(() => splitCue(reversed, const Duration(seconds: 2)), throwsFormatException);
    const valid = SubtitleCue(start: Duration(seconds: 1), end: Duration(seconds: 3), original: 'Good');
    expect(splitCue(valid, const Duration(seconds: 2)), hasLength(2));
  });

}
