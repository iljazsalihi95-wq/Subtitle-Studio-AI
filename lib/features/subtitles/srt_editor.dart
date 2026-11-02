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

/// Exports WebVTT without changing the source cue timings.
String exportVtt(List<SubtitleCue> cues, {bool translated = true}) {
  final body = cues.map((cue) {
    final text = translated ? cue.translation : cue.original;
    final start = _timestamp(cue.start).replaceAll(',', '.');
    final end = _timestamp(cue.end).replaceAll(',', '.');
    return '$start --> $end\n$text';
  }).join('\n\n');
  return body.isEmpty ? 'WEBVTT\n' : 'WEBVTT\n\n$body\n';
}

Duration _parseTimestamp(String value) {
  final match = RegExp(r'^(\d{2}):(\d{2}):(\d{2})[,.](\d{3})$').firstMatch(value.trim());
  if (match == null) throw FormatException('Invalid subtitle timestamp: $value');
  final parts = List.generate(4, (index) => int.parse(match.group(index + 1)!));
  if (parts[1] >= 60 || parts[2] >= 60) throw FormatException('Invalid subtitle timestamp: $value');
  return Duration(hours: parts[0], minutes: parts[1], seconds: parts[2], milliseconds: parts[3]);
}

/// Reads local SRT or WebVTT cues without changing their timing.
List<SubtitleCue> parseSubtitles(String source) {
  final normalized = source.replaceAll('\r\n', '\n').replaceAll('\r', '\n').replaceFirst('\uFEFF', '');
  final blocks = normalized.split(RegExp(r'\n\s*\n'));
  final cues = <SubtitleCue>[];
  for (final block in blocks) {
    final lines = block.trim().split('\n');
    if (lines.isEmpty || lines.first.trim() == 'WEBVTT' || lines.first.startsWith('NOTE')) continue;
    final timeIndex = lines.indexWhere((line) => line.contains('-->'));
    if (timeIndex < 0 || timeIndex >= lines.length - 1) continue;
    final times = lines[timeIndex].split('-->');
    if (times.length != 2) continue;
    final endToken = times[1].trim().split(RegExp(r'\s+')).first;
    final start = _parseTimestamp(times[0]);
    final end = _parseTimestamp(endToken);
    if (end <= start) throw const FormatException('Subtitle end must follow start');
    cues.add(SubtitleCue(start: start, end: end, original: lines.skip(timeIndex + 1).join('\n')));
  }
  return cues;
}
