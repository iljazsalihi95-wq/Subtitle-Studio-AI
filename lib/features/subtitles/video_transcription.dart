import 'dart:io';
import 'package:flutter/services.dart';
import '../ai/ai_connection.dart';
import 'srt_editor.dart';

List<SubtitleCue> timedSegments(List<dynamic> segments, int offsetUs) {
  if (offsetUs < 0) {
    throw const FormatException('Pozicioni i audios nuk mund të jetë negativ.');
  }
  final cues = <SubtitleCue>[];
  for (final item in segments) {
    if (item is! Map || item['start'] is! num || item['end'] is! num || item['text'] is! String) {
      throw const FormatException('Transkriptimi ka të dhëna të pavlefshme.');
    }
    final start = (item['start'] as num).toDouble();
    final end = (item['end'] as num).toDouble();
    final text = (item['text'] as String).trim();
    if (!start.isFinite || !end.isFinite || start < 0 || end <= start) {
      throw const FormatException('Koha e transkriptimit është e pavlefshme.');
    }
    if (text.isEmpty) continue;
    cues.add(SubtitleCue(
      start: Duration(microseconds: offsetUs + (start * 1000000).round()),
      end: Duration(microseconds: offsetUs + (end * 1000000).round()),
      original: text,
    ));
  }
  return cues;
}


/// Validates native chunk metadata before applying timestamps or deleting audio.
({int offsetUs, int nextUs}) validatedChunkTimes(
    Map<String, dynamic> chunk, int currentUs) {
  final offset = chunk['offsetUs'];
  final next = chunk['nextUs'];
  if (offset is! int || next is! int ||
      currentUs < 0 || offset < currentUs || offset >= next ||
      next <= currentUs) {
    throw const FormatException('Koha e pjesës audio është e pavlefshme.');
  }
  return (offsetUs: offset, nextUs: next);
}

class TranscriptionProgress {
  const TranscriptionProgress(this.cues, this.processedUs);
  final List<SubtitleCue> cues;
  final int processedUs;
}

Stream<TranscriptionProgress> transcribeVideo(String path, bool Function() cancelled) async* {
  const channel = MethodChannel('subtitle_studio/audio');
  var position = 0;
  final cues = <SubtitleCue>[];
  while (!cancelled()) {
    final chunk = await channel.invokeMapMethod<String, dynamic>('extractChunk', {'path': path, 'startUs': position});
    if (chunk == null) throw const FormatException('Nxjerrja e audios nuk u përgjigj.');
    // Reject invalid timing before uploading audio to the transcription service.
    // A malformed native chunk must never incur an API request.
    final audioPath = chunk['path'] as String?;
    if (audioPath == null) {
      if (chunk['done'] == true) break;
      throw const FormatException('Audioja nuk u krijua.');
    }
    final audio = File(audioPath);
    try {
      final times = validatedChunkTimes(chunk, position);
      if (cancelled()) break;
      final segments = await transcribeAudio(audio);
      if (cancelled()) break;
      cues.addAll(timedSegments(segments, times.offsetUs));
      position = times.nextUs;
      yield TranscriptionProgress(List<SubtitleCue>.of(cues), position);
    } finally {
      if (await audio.exists()) await audio.delete();
    }
    if (chunk['done'] == true) break;
  }
}
