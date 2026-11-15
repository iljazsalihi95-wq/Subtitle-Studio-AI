import 'package:flutter_test/flutter_test.dart';
import 'package:subtitle_studio_ai/features/subtitles/srt_editor.dart';

void main() {
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

  test('Invalid timestamps are rejected rather than silently retimed', () {
    expect(
      () => parseSubtitles('1\n00:00:61,000 --> 00:01:02,000\nGabim'),
      throwsFormatException,
    );
  });
}
