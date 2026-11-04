import 'package:flutter_test/flutter_test.dart';
import 'package:subtitle_studio_ai/features/subtitles/srt_editor.dart';

void main() {
  test('WebVTT imports a cue directly after its header', () {
    const source = 'WEBVTT\n00:00:01.000 --> 00:00:03.000\nPërshëndetje';
    final cues = parseSubtitles(source);
    expect(cues, hasLength(1));
    expect(cues.single.start, const Duration(seconds: 1));
    expect(cues.single.original, 'Përshëndetje');
  });

  test('standard WebVTT header and blank line remain supported', () {
    const source = 'WEBVTT\n\n00:00:02.000 --> 00:00:04.000\nHello';
    final cues = parseSubtitles(source);
    expect(cues, hasLength(1));
    expect(cues.single.original, 'Hello');
  });
}
