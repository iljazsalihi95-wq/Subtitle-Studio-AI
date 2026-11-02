import 'package:flutter_test/flutter_test.dart';
import 'package:subtitle_studio_ai/features/subtitles/srt_editor.dart';
void main() {
  test('Translation keeps original timecodes', () {
    final cue = SubtitleCue(start: const Duration(seconds: 1), end: const Duration(milliseconds: 3500), original: 'Merhaba').translated('Përshëndetje');
    expect(exportSrt([cue]), contains('00:00:01,000 --> 00:00:03,500'));
    expect(exportSrt([cue]), contains('Përshëndetje'));
    expect(exportSrt([cue], translated: false), contains('Merhaba'));
  });
}
