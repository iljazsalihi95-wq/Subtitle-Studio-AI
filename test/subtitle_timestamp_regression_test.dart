import 'package:flutter_test/flutter_test.dart';
import 'package:subtitle_studio_ai/features/subtitles/srt_editor.dart';

void main() {
  test('Timing shifts preserve sub-millisecond precision until export', () {
    final cue = SubtitleCue(
      start: const Duration(microseconds: 1500),
      end: const Duration(microseconds: 2500),
      original: 'Test',
    );
    final shifted = shiftSubtitleTiming([cue], const Duration(microseconds: -500));
    expect(shifted.single.start.inMicroseconds, 1000);
    expect(shifted.single.end.inMicroseconds, 2000);
    expect(
      () => shiftSubtitleTiming([cue], const Duration(microseconds: -1501)),
      throwsFormatException,
    );
  });

  test('SRT timestamp with one digit fraction is scaled to milliseconds', () {
    final cues = parseSubtitles('1\n00:00:01,5 --> 00:00:02,25\nPërshëndetje');
    expect(cues, hasLength(1));
    expect(cues.single.start.inMilliseconds, 1500);
    expect(cues.single.end.inMilliseconds, 2250);
    expect(cues.single.original, 'Përshëndetje');
  });

  test('VTT minute timestamps and BOM import correctly', () {
    final cues = parseSubtitles('\uFEFFWEBVTT\n\n00:01.250 --> 00:02.500\nNjë fjali');
    expect(cues, hasLength(1));
    expect(cues.single.start.inMilliseconds, 1250);
    expect(cues.single.end.inMilliseconds, 2500);
  });

  test('WebVTT short timestamps reject minute values above 59', () {
    expect(
      () => parseSubtitles('WEBVTT\n\n60:00.000 --> 60:01.000\nGabim'),
      throwsFormatException,
    );
    expect(
      () => parseSubtitles('WEBVTT\n\n59:59.000 --> 60:00.000\nGabim'),
      throwsFormatException,
    );
  });

  test('Invalid timestamps are rejected rather than silently retimed', () {
    expect(
      () => parseSubtitles('1\n00:00:61,000 --> 00:01:02,000\nGabim'),
      throwsFormatException,
    );
  });
}
