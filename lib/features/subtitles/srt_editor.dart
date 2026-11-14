import 'dart:convert';
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
  if (cues.any((cue) => cue.start.inMilliseconds + delta < 0 ||
      cue.end <= cue.start)) {
    throw const FormatException('Subtitle timing is negative or invalid');
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
  // Validate emptiness in editor order, but detect overlaps chronologically:
  // imported cues can be out of order. Return original editor indexes.
  for (var i = 0; i < cues.length; i++) {
    final cue = cues[i];
    if ((cue.original.trim().isEmpty && cue.translation.trim().isEmpty) ||
        cue.start.isNegative || cue.end <= cue.start) {
      empty.add(i);
    }
  }
  final order = List<int>.generate(cues.length, (i) => i)
    ..sort((a, b) {
      final byStart = cues[a].start.compareTo(cues[b].start);
      return byStart != 0 ? byStart : a.compareTo(b);
    });
  Duration? latestEnd;
  for (final index in order) {
    final cue = cues[index];
    if (latestEnd != null && cue.start < latestEnd) overlaps.add(index);
    if (latestEnd == null || cue.end > latestEnd) latestEnd = cue.end;
  }
  overlaps.sort();
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
  if ((match.group(1) != null && minutes >= 60) || seconds >= 60) {
    throw FormatException('Invalid subtitle timestamp: $value');
  }
  return Duration(hours: hours, minutes: minutes, seconds: seconds, milliseconds: milliseconds);
}

/// Reads local SRT or WebVTT cues without changing their timing.
List<SubtitleCue> parseSubtitles(String source) {
  final normalized = source.replaceAll('\r\n', '\n').replaceAll('\r', '\n').replaceFirst('\uFEFF', '');
  final isVtt = normalized.startsWith('WEBVTT');
  // Remove only the WEBVTT signature line. Searching for the first blank
  // line can discard the first cue when a file omits the header separator.
  final firstLineEnd = normalized.indexOf('\n');
  final body = isVtt
      ? (firstLineEnd < 0 ? '' : normalized.substring(firstLineEnd + 1).trimLeft())
      : normalized;
  final blocks = body.split(RegExp(r'\n\s*\n'));
  final cues = <SubtitleCue>[];
  for (final block in blocks) {
    final lines = block.trim().split('\n');
    if (lines.isEmpty || lines.first.trim() == 'WEBVTT' || RegExp(r'^(NOTE|STYLE|REGION)(\s|$)').hasMatch(lines.first.trim())) continue;
    final timeIndex = lines.indexWhere((line) => line.contains('-->'));
    if (timeIndex < 0 || timeIndex >= lines.length - 1) continue;
    // Ignore metadata and comments before the timing line, but retain multiline cue text.
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


class SubtitleProject {
  const SubtitleProject({required this.title, required this.cues, this.videoPath});
  final String title;
  final String? videoPath;
  final List<SubtitleCue> cues;
}

String encodeProject(SubtitleProject project) => jsonEncode({
  'format': 'subtitle-studio-ai', 'version': 1, 'title': project.title,
  'videoPath': project.videoPath,
  'cues': [for (final c in project.cues) {'start': c.start.inMilliseconds, 'end': c.end.inMilliseconds, 'original': c.original, 'translation': c.translation}],
});

SubtitleProject decodeProject(String source) {
  // Accept a real UTF-8 BOM in project files exported by desktop editors.
  final normalized = source.startsWith('\uFEFF') ? source.substring(1) : source;
  final data = jsonDecode(normalized);
  if (data is! Map || data['format'] != 'subtitle-studio-ai' || data['version'] != 1 || data['title'] is! String || data['cues'] is! List || (data['videoPath'] != null && data['videoPath'] is! String)) throw const FormatException('Invalid project');
  final cues = <SubtitleCue>[];
  for (final c in data['cues']) {
    if (c is! Map || c['start'] is! int || c['end'] is! int || c['start'] < 0 || c['end'] <= c['start'] || c['original'] is! String || c['translation'] is! String) throw const FormatException('Invalid cue');
    cues.add(SubtitleCue(start: Duration(milliseconds: c['start']), end: Duration(milliseconds: c['end']), original: c['original'], translation: c['translation']));
  }
  return SubtitleProject(title: data['title'], videoPath: data['videoPath'], cues: cues);
}

List<SubtitleCue> splitCue(SubtitleCue cue, Duration position) {
  if (position <= cue.start || position >= cue.end) throw const FormatException('Split outside cue');
  return [SubtitleCue(start: cue.start, end: position, original: cue.original, translation: cue.translation), SubtitleCue(start: position, end: cue.end, original: cue.original, translation: cue.translation)];
}
SubtitleCue mergeCues(SubtitleCue first, SubtitleCue second) {
  String combine(String a, String b) => [a, b].where((s) => s.trim().isNotEmpty).join('\n');
  return SubtitleCue(start: first.start < second.start ? first.start : second.start, end: first.end > second.end ? first.end : second.end, original: combine(first.original, second.original), translation: combine(first.translation.isEmpty ? first.original : first.translation, second.translation.isEmpty ? second.original : second.translation));
}
