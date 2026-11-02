class SubtitleCue {
  const SubtitleCue({required this.start, required this.end, required this.original, this.translation = ''});
  final Duration start;
  final Duration end;
  final String original;
  final String translation;
  SubtitleCue translated(String text) => SubtitleCue(start: start, end: end, original: original, translation: text);
}
String _timestamp(Duration time) {
  final hours = time.inHours.toString().padLeft(2, '0');
  final minutes = (time.inMinutes % 60).toString().padLeft(2, '0');
  final seconds = (time.inSeconds % 60).toString().padLeft(2, '0');
  final milliseconds = (time.inMilliseconds % 1000).toString().padLeft(3, '0');
  return '$hours:$minutes:$seconds,$milliseconds';
}
String exportSrt(List<SubtitleCue> cues, {bool translated = true}) {
  return cues.asMap().entries.map((entry) {
    final cue = entry.value;
    final text = translated ? cue.translation : cue.original;
    return '${entry.key + 1}\n${_timestamp(cue.start)} --> ${_timestamp(cue.end)}\n$text';
  }).join('\n\n');
}
