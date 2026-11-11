import 'package:flutter_test/flutter_test.dart';
import 'package:subtitle_studio_ai/features/subtitles/video_transcription.dart';

void main() {
  test('offsets chunk timestamps onto the full video without changing Arabic', () {
    final cues = timedSegments([{'start': 0.125, 'end': 2.5, 'text': 'السلام عليكم'}], 180000000);
    expect(cues.single.start.inMilliseconds, 180125);
    expect(cues.single.end.inMilliseconds, 182500);
    expect(cues.single.original, 'السلام عليكم');
    expect(cues.single.translation, '');
  });
  test('validates native audio chunk cursor and sample offset', () {
    expect(validatedChunkTimes({'offsetUs': 125000, 'nextUs': 180000000}, 0).offsetUs, 125000);
    expect(() => validatedChunkTimes({'offsetUs': -1, 'nextUs': 10}, 0), throwsFormatException);
    expect(() => validatedChunkTimes({'offsetUs': 5, 'nextUs': 5}, 0), throwsFormatException);
    expect(() => validatedChunkTimes({'offsetUs': 0, 'nextUs': 10}, 5), throwsFormatException);
    expect(() => validatedChunkTimes({'offsetUs': '0', 'nextUs': 10}, 0), throwsFormatException);
    expect(() => validatedChunkTimes({'offsetUs': 0, 'nextUs': double.nan}, 0), throwsFormatException);
  });
  test('rejects malformed or reversed transcription timestamps', () {
    expect(() => timedSegments([{'start': 3, 'end': 2, 'text': 'x'}], 0), throwsFormatException);
    expect(() => timedSegments([{'start': double.nan, 'end': 2, 'text': 'x'}], 0), throwsFormatException);
    expect(() => timedSegments([{'text': 'x'}], 0), throwsFormatException);
    expect(() => timedSegments([{'start': 0, 'end': 1, 'text': 'x'}], -1), throwsFormatException);
  });
}
