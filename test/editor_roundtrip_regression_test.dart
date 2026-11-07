import 'package:flutter_test/flutter_test.dart';
import 'package:subtitle_studio_ai/features/subtitles/srt_editor.dart';

void main() {
  test('SRT and VTT exports preserve timings and multiline Albanian text', () {
    final cues = [
      SubtitleCue(
        start: const Duration(milliseconds: 1250),
        end: const Duration(milliseconds: 3750),
        original: 'Përshëndetje\nMirë se erdhët',
        translation: 'Welcome\nEveryone',
      ),
    ];
    final srt = parseSubtitles(exportSrt(cues, translated: false));
    final vtt = parseSubtitles(exportVtt(cues, translated: false));
    for (final parsed in [srt, vtt]) {
      expect(parsed, hasLength(1));
      expect(parsed.single.start, cues.single.start);
      expect(parsed.single.end, cues.single.end);
      expect(parsed.single.original, cues.single.original);
    }
  });

  test('saved project roundtrip retains translations and local video path', () {
    final project = SubtitleProject(
      title: 'Projekti im',
      videoPath: '/private/video.mp4',
      cues: [
        SubtitleCue(
          start: const Duration(seconds: 2),
          end: const Duration(seconds: 4),
          original: 'Teksti origjinal',
          translation: 'Përkthimi shqip',
        ),
      ],
    );
    final restored = decodeProject(encodeProject(project));
    expect(restored.title, project.title);
    expect(restored.videoPath, project.videoPath);
    expect(restored.cues.single.translation, 'Përkthimi shqip');
  });

  test('rejects invalid subtitle timing and corrupt saved projects', () {
    expect(
      () => parseSubtitles('1\n00:00:04,000 --> 00:00:02,000\nGabim'),
      throwsFormatException,
    );
    expect(
      () => decodeProject('{"format":"subtitle-studio-ai","version":1,"title":"x","cues":[{"start":4000,"end":2000,"original":"x","translation":""}]}'),
      throwsFormatException,
    );
  });
}
