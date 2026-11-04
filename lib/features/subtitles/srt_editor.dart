class SubtitleCue {
  const SubtitleCue({required this.start, required this.end, required this.original, this.translation = ''});
  final Duration start;
  final Duration end;
  final String original;
  final String translation;
  SubtitleCue translated(String text) => SubtitleCue(start: start, end: end, original: original, translation: text);
}


/// Moves all cue timestamps by [offset] without modifying text.
/// Rejects shifts that would place a subtitle before the start of the video.
List<SubtitleCue> shiftSubtitleTiming(List<SubtitleCue> cues, Duration offset) {
  final delta = offset.inMilliseconds;
  if (cues.any((cue) => cue.start.inMilliseconds + delta < 0)) {
    throw const FormatException('Subtitle timing cannot be negative');
  }
  return [
    for (final cue in cues)
      SubtitleCue(
        start: Duration(milliseconds: cue.start.inMilliseconds + delta),
        end: Duration(milliseconds: cue.end.inMilliseconds + delta),
        original: cue.original,
        translation: cue.translation,
      ),
  ];
}

class SubtitleTimelineReport {
  const SubtitleTimelineReport({required this.overlapIndexes, required this.emptyIndexes});
  final List<int> overlapIndexes;
  final List<int> emptyIndexes;
  bool get isClean => overlapIndexes.isEmpty && emptyIndexes.isEmpty;
}

/// Checks imported/edited cues without changing their timing.
/// Indexes are zero-based so the UI can jump directly to the affected cue.
SubtitleTimelineReport validateTimeline(List<SubtitleCue> cues) {
  final overlaps = <int>[];
  final empty = <int>[];
  for (var i = 0; i < cues.length; i++) {
    final cue = cues[i];
    if (cue.original.trim().isEmpty && cue.translation.trim().isEmpty) empty.add(i);
    if ((cue.start.isNegative || cue.end <= cue.start) && !empty.contains(i)) empty.add(i);
    if (i > 0 && cue.start < cues[i - 1].end) overlaps.add(i);
  }
  return SubtitleTimelineReport(overlapIndexes: overlaps, emptyIndexes: empty);
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
    final text = translated && cue.translation.trim().isNotEmpty ? cue.translation : cue.original;
    return '${entry.key + 1}\n${_timestamp(cue.start)} --> ${_timestamp(cue.end)}\n$text';
  }).join('\n\n');
}

/// Exports WebVTT without changing the source cue timings.
String exportVtt(List<SubtitleCue> cues, {bool translated = true}) {
  final body = cues.map((cue) {
    final text = translated && cue.translation.trim().isNotEmpty ? cue.translation : cue.original;
    final start = _timestamp(cue.start).replaceAll(',', '.');
    final end = _timestamp(cue.end).replaceAll(',', '.');
    return '$start --> $end\n$text';
  }).join('\n\n');
  return body.isEmpty ? 'WEBVTT\n' : 'WEBVTT\n\n$body\n';
}

Duration _parseTimestamp(String value) {
  final token = value.trim();
  // WebVTT allows MM:SS.mmm; SRT and WebVTT also allow HH:MM:SS.mmm.
  final match = RegExp(r'^(?:(\d{2,}):)?(\d{2}):(\d{2})[,.](\d{3})$').firstMatch(token);
  if (match == null) throw FormatException('Invalid subtitle timestamp: $value');
  final hours = int.tryParse(match.group(1) ?? '0')!;
  final minutes = int.parse(match.group(2)!);
  final seconds = int.parse(match.group(3)!);
  final milliseconds = int.parse(match.group(4)!);
  if (minutes >= 60 || seconds >= 60) {
    throw FormatException('Invalid subtitle timestamp: $value');
  }
  return Duration(hours: hours, minutes: minutes, seconds: seconds, milliseconds: milliseconds);
}

/// Reads local SRT or WebVTT cues without changing their timing.
List<SubtitleCue> parseSubtitles(String source) {
  final normalized = source.replaceAll('\r\n', '\n').replaceAll('\r', '\n').replaceFirst('\uFEFF', '');
  final isVtt = normalized.startsWith('WEBVTT');
  // The WebVTT header ends at its first blank line. Never consume cue blocks.
  final headerEnd = normalized.indexOf(RegExp(r'\n\s*\n'));
  final body = isVtt
      ? (headerEnd < 0 ? '' : normalized.substring(headerEnd).trimLeft())
      : normalized;
  final blocks = body.split(RegExp(r'\n\s*\n'));
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
