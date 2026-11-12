import 'package:flutter_test/flutter_test.dart';
import 'package:subtitle_studio_ai/features/subtitles/srt_editor.dart';
void main() {
  const cue = SubtitleCue(start: Duration(seconds: 1), end: Duration(seconds: 5), original: 'orig', translation: 'shqip');
  test('project round trip preserves original and translation separately', () {
    final restored = decodeProject(encodeProject(const SubtitleProject(title: 'test', cues: [cue], videoPath: '/video.mp4')));
    expect(restored.cues.single.original, 'orig');
    expect(restored.cues.single.translation, 'shqip');
    expect(restored.videoPath, '/video.mp4');
    expect(restored.cues.single.end, const Duration(seconds: 5));
  });
  test('split preserves exact boundaries and refuses out of range position', () {
    final parts = splitCue(cue, const Duration(seconds: 3));
    expect(parts.first.end, parts.last.start);
    expect(parts.last.end, cue.end);
    expect(() => splitCue(cue, cue.end), throwsFormatException);
  });
  test('merge retains untranslated second cue', () {
    final merged = mergeCues(cue, const SubtitleCue(start: Duration(seconds: 5), end: Duration(seconds: 7), original: 'second'));
    expect(merged.translation, 'shqip\nsecond');
  });
  test('project import accepts UTF-8 BOM without losing cues', () {
    final encoded = encodeProject(const SubtitleProject(title: 'BOM', cues: [cue]));
    final restored = decodeProject('\uFEFF$encoded');
    expect(restored.title, 'BOM');
    expect(restored.cues.single.translation, 'shqip');
  });
  test('invalid project timing is rejected', () {
    expect(() => decodeProject('{"format":"subtitle-studio-ai","version":1,"title":"x","cues":[{"start":4,"end":1,"original":"a","translation":"b"}]}'), throwsFormatException);
  });
}
