import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';
import 'features/subtitles/srt_editor.dart';

void main() => runApp(const StudioApp());

class StudioApp extends StatelessWidget {
  const StudioApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'Subtitle Studio AI',
        theme: ThemeData(
          brightness: Brightness.dark,
          scaffoldBackgroundColor: const Color(0xFF07111F),
          colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFFE8C170), brightness: Brightness.dark),
          useMaterial3: true,
        ),
        home: const HomePage(),
      );
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});
  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  String? selectedFile;
  String? selectedVideoPath;

  Future<void> _import() async {
    try {
      final files = await FilePicker.pickFiles(type: FileType.custom, allowedExtensions: ['mp4', 'mkv', 'mov', 'webm', 'srt', 'vtt']);
      if (!mounted || files.isEmpty) return;
      final file = files.single;
      if (['srt', 'vtt'].contains(file.extension?.toLowerCase()) && file.path != null && await File(file.path!).length() > 20 * 1024 * 1024) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Skedari i titrave është mbi 20 MB. Zgjidh një SRT/VTT më të vogël.')));
        return;
      }
      if (['srt', 'vtt'].contains(file.extension?.toLowerCase())) {
        final bytes = await file.readAsBytes();
        final cues = parseSubtitles(utf8.decode(bytes, allowMalformed: true));
        if (!mounted) return;
        if (cues.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Nuk u gjet asnjë titër i vlefshëm SRT/VTT. Kontrollo formatin e skedarit.')));
          return;
        }
        setState(() => selectedFile = file.name);
        await Navigator.push(context, MaterialPageRoute<void>(builder: (_) => SubtitlePreviewPage(filename: file.name, cues: cues, videoPath: selectedVideoPath)));
        return;
      }
      if (!mounted) return;
      if (file.path == null) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Nuk mund të lexohet rruga e videos.')));
        return;
      }
      setState(() { selectedFile = file.name; selectedVideoPath = file.path; });
      _newSubtitleProject();
    } on FormatException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Formati i titrave është i pavlefshëm: ${error.message}')));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Skedari nuk mund të zgjidhej. Provo përsëri.')));
    }
  }

  Future<void> _openVideoStudio() async {
    try {
      final files = await FilePicker.pickFiles(type: FileType.video);
      if (!mounted || files.isEmpty) return;
      final file = files.single;
      if (file.path == null) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Nuk mund të hapet videoja e zgjedhur.')));
        return;
      }
      setState(() { selectedFile = file.name; selectedVideoPath = file.path; });
      _newSubtitleProject();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Zgjedhja e videos dështoi.')));
    }
  }

  void _newSubtitleProject() {
    Navigator.push(context, MaterialPageRoute<void>(builder: (_) => SubtitlePreviewPage(
      filename: 'projekt_i_ri.srt',
      videoPath: selectedVideoPath,
      cues: [SubtitleCue(start: Duration.zero, end: const Duration(seconds: 3), original: '', translation: '')],
    )));
  }

  Future<void> _openSubtitleStudio() async {
    try {
      final files = await FilePicker.pickFiles(type: FileType.custom, allowedExtensions: ['srt', 'vtt']);
      if (!mounted || files.isEmpty) return;
      final file = files.single;
      if ((file.path != null && File(file.path!).lengthSync() > 20 * 1024 * 1024)) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Skedari i titrave është mbi 20 MB.')));
        return;
      }
      final cues = parseSubtitles(utf8.decode(await file.readAsBytes(), allowMalformed: true));
      if (!mounted) return;
      if (cues.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Nuk u gjet asnjë titër i vlefshëm SRT/VTT.')));
        return;
      }
      await Navigator.push(context, MaterialPageRoute<void>(builder: (_) => SubtitlePreviewPage(filename: file.name, cues: cues, videoPath: selectedVideoPath)));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Titrat nuk mund të hapeshin.')));
    }
  }

  void _showModuleInfo(String title, String message) {
    if (!mounted) return;
    showModalBottomSheet<void>(context: context, showDragHandle: true, builder: (sheetContext) => SafeArea(child: Padding(padding: const EdgeInsets.all(24), child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: Theme.of(sheetContext).textTheme.headlineSmall), const SizedBox(height: 12), Text(message), const SizedBox(height: 18), FilledButton(onPressed: () => Navigator.pop(sheetContext), child: const Text('Mbyll'))]))));
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(child: ListView(padding: const EdgeInsets.fromLTRB(20, 18, 20, 28), children: [
      const _Brand(), const SizedBox(height: 28),
      Text('Studio profesionale për titrat e tu.', style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w800)),
      const SizedBox(height: 8), const Text('Importo • kontrollo timeline-in • përkthe • eksporto', style: TextStyle(color: Color(0xFFB7C2D0), height: 1.45)),
      const SizedBox(height: 24),
      _Action(icon: Icons.video_file_outlined, title: 'Projekt i ri', subtitle: selectedFile ?? 'Video • SRT • VTT', primary: true, onTap: _import),
      _Action(icon: Icons.subtitles_outlined, title: 'Studio me video', subtitle: 'Zgjidh videon • shiko • sinkronizo titrat', onTap: _openVideoStudio),
      _Action(icon: Icons.file_open_outlined, title: 'Importo titra ekzistues', subtitle: 'Zgjidh një skedar SRT ose VTT', onTap: _openSubtitleStudio),
      _Action(icon: Icons.translate, title: 'Përkthimi AI', subtitle: 'Shqip • kërkon lidhjen e backend-it', onTap: () => _showModuleInfo('Përkthimi AI', 'Lidhja me backend-in AI nuk është konfiguruar ende në këtë APK. Redaktimi manual dhe eksporti SRT/VTT funksionojnë pa internet.')),
      _Action(icon: Icons.ios_share_outlined, title: 'Eksporto', subtitle: 'Hap titrat për eksport SRT • VTT', onTap: _openSubtitleStudio),
      const SizedBox(height: 18), const _Status(),
    ])),
    bottomNavigationBar: NavigationBar(selectedIndex: 0, onDestinationSelected: (index) { if (index == 1) { _openVideoStudio(); } else if (index == 2) { _showModuleInfo('Përkthimi AI', 'Përkthimi kërkon lidhjen me backend-in privat.'); } else if (index == 3) { _showModuleInfo('Projektet', 'Projektet ruhen lokalisht pasi të aktivizohet ruajtja e tyre.'); } }, destinations: const [
      NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home), label: 'Ballina'),
      NavigationDestination(icon: Icon(Icons.subtitles_outlined), label: 'Studio'),
      NavigationDestination(icon: Icon(Icons.auto_awesome_outlined), label: 'AI'),
      NavigationDestination(icon: Icon(Icons.folder_outlined), label: 'Projektet'),
    ]),
  );
}

class _Brand extends StatelessWidget {
  const _Brand();
  @override
  Widget build(BuildContext context) => const Row(children: [_Mark(), SizedBox(width: 14), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('SUBTITLE STUDIO AI', style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1.4, fontSize: 17)), SizedBox(height: 3), Text('CREATE • TRANSLATE • SYNC', style: TextStyle(color: Color(0xFFE8C170), fontSize: 11, letterSpacing: 1.1))]))]);
}

class _Mark extends StatelessWidget {
  const _Mark();
  @override
  Widget build(BuildContext context) => Container(width: 58, height: 58, decoration: BoxDecoration(borderRadius: BorderRadius.circular(16), gradient: const LinearGradient(colors: [Color(0xFF263A55), Color(0xFF101D30)]), border: Border.all(color: const Color(0xFFE8C170), width: 1.2)), child: const Stack(alignment: Alignment.center, children: [Icon(Icons.movie_filter_outlined, color: Color(0xFFE8C170), size: 34), Positioned(bottom: 8, child: Text('CC', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900)))]));
}

class _Action extends StatelessWidget {
  const _Action({required this.icon, required this.title, required this.subtitle, this.primary = false, this.onTap});
  final IconData icon; final String title, subtitle; final bool primary; final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) => Padding(padding: const EdgeInsets.only(bottom: 12), child: Material(color: primary ? const Color(0xFF182A42) : const Color(0xFF101C2C), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18), side: BorderSide(color: primary ? const Color(0xFFE8C170).withValues(alpha: .65) : const Color(0xFF26364B))), clipBehavior: Clip.antiAlias, child: ListTile(onTap: onTap ?? () => _showStatus(context), contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8), leading: Container(width: 44, height: 44, decoration: BoxDecoration(color: const Color(0xFFE8C170).withValues(alpha: .10), borderRadius: BorderRadius.circular(13)), child: Icon(icon, color: const Color(0xFFE8C170))), title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)), subtitle: Text(subtitle, style: const TextStyle(color: Color(0xFF9EABBC))), trailing: const Icon(Icons.chevron_right, color: Color(0xFFE8C170)))));
  void _showStatus(BuildContext context) => showModalBottomSheet<void>(context: context, showDragHandle: true, builder: (c) => SafeArea(child: Padding(padding: const EdgeInsets.all(24), child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: Theme.of(context).textTheme.headlineSmall), const SizedBox(height: 12), Text(subtitle), const SizedBox(height: 18), const Text('Ky modul kërkon backend-in privat AI.', style: TextStyle(color: Colors.grey)), const SizedBox(height: 18), FilledButton(onPressed: () => Navigator.pop(c), child: const Text('Mbyll'))]))));
}

class _Status extends StatelessWidget {
  const _Status();
  @override
  Widget build(BuildContext context) => const Row(children: [Icon(Icons.shield_outlined, size: 17, color: Color(0xFF7F91A8)), SizedBox(width: 8), Expanded(child: Text('Skedarët lokalë • pa API keys në APK', style: TextStyle(color: Color(0xFF7F91A8), fontSize: 12)))]);
}

class SubtitlePreviewPage extends StatefulWidget {
  const SubtitlePreviewPage({super.key, required this.filename, required this.cues, this.videoPath});
  final String filename; final List<SubtitleCue> cues; final String? videoPath;
  @override State<SubtitlePreviewPage> createState() => _SubtitlePreviewPageState();
}

class _SubtitlePreviewPageState extends State<SubtitlePreviewPage> {
  late final List<TextEditingController> translations;
  late List<SubtitleCue> timedCues;
  final TextEditingController offsetMs = TextEditingController(text: '0');
  final TextEditingController cueSearch = TextEditingController();
  String searchQuery = '';
  VideoPlayerController? videoController;
  bool videoLoading = false;
  double playbackSpeed = 1.0;
  Future<void> _pickVideo() async {
    final files = await FilePicker.pickFiles(type: FileType.video);
    if (!mounted || files.isEmpty || files.single.path == null) return;
    await _loadVideo(files.single.path!);
  }
  Future<void> _loadVideo(String path) async {
    setState(() => videoLoading = true);
    final next = VideoPlayerController.file(File(path));
    try {
      await next.initialize();
      await next.setPlaybackSpeed(playbackSpeed);
      if (!mounted) { await next.dispose(); return; }
      final old = videoController;
      setState(() { videoController = next; videoLoading = false; });
      await old?.dispose();
    } catch (_) {
      await next.dispose();
      if (!mounted) return;
      setState(() => videoLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Videoja nuk mund të luhet në këtë pajisje.')));
    }
  }
  bool onlyProblems = false;
  void _deleteCue(int index) {
    if (timedCues.length <= 1) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Projekti duhet të ketë të paktën një titër.')));
      return;
    }
    final removed = translations[index];
    removed.removeListener(_onTranslationChanged);
    setState(() {
      timedCues.removeAt(index);
      translations.removeAt(index);
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => removed.dispose());
  }
  void _addCue() {
    final position = videoController?.value.position;
    final start = position ?? (timedCues.isEmpty ? Duration.zero : timedCues.last.end);
    final videoDuration = videoController?.value.duration;
    if (videoDuration != null && start >= videoDuration) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Shko më herët në video për të shtuar titër.')));
      return;
    }
    final insertAt = timedCues.indexWhere((cue) => cue.start > start);
    final index = insertAt < 0 ? timedCues.length : insertAt;
    var end = start + const Duration(seconds: 3);
    if (videoDuration != null && end > videoDuration) end = videoDuration;
    if (index < timedCues.length && end > timedCues[index].start) end = timedCues[index].start;
    if (end <= start) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Nuk ka hapësirë për titër në këtë pozicion.')));
      return;
    }
    final controller = TextEditingController()..addListener(_onTranslationChanged);
    setState(() {
      timedCues.insert(index, SubtitleCue(start: start, end: end, original: '', translation: ''));
      translations.insert(index, controller);
      onlyProblems = false;
      searchQuery = '';
      cueSearch.clear();
    });
  }
  void _markCueBoundary(int index, {required bool start}) {
    final player = videoController;
    if (player == null || !player.value.isInitialized) return;
    final position = player.value.position;
    final cue = timedCues[index];
    final newStart = start ? position : cue.start;
    final newEnd = start ? cue.end : position;
    if (newEnd <= newStart) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Fundi duhet të jetë pas fillimit të titrit.')));
      return;
    }
    setState(() => timedCues[index] = SubtitleCue(
      start: newStart, end: newEnd, original: cue.original,
      translation: translations[index].text,
    ));
  }
  void _shift() {
    final value = int.tryParse(offsetMs.text.trim());
    if (value == null) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Shkruaj milisekonda, p.sh. 1500 ose -500.'))); return; }
    try { setState(() => timedCues = shiftSubtitleTiming(timedCues, Duration(milliseconds: value))); }
    on FormatException { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Koha nuk mund të jetë negative.'))); }
  }
  @override void initState() { super.initState(); if (widget.videoPath != null) { WidgetsBinding.instance.addPostFrameCallback((_) { if (mounted) _loadVideo(widget.videoPath!); }); } timedCues = List.of(widget.cues); translations = timedCues.map((cue) => TextEditingController(text: cue.translation)).toList(); for (final controller in translations) { controller.addListener(_onTranslationChanged); } }
  void _onTranslationChanged() { if (mounted) setState(() {}); }
  @override void dispose() { for (final controller in translations) { controller.dispose(); } offsetMs.dispose(); cueSearch.dispose(); videoController?.dispose(); super.dispose(); }
  List<SubtitleCue> get editedCues => [for (var i = 0; i < timedCues.length; i++) timedCues[i].translated(translations[i].text)];
  void _showExport(bool vtt) {
    final output = vtt ? exportVtt(editedCues) : exportSrt(editedCues);
    showDialog<void>(context: context, builder: (dialogContext) => AlertDialog(
      title: Text(vtt ? 'Eksport VTT' : 'Eksport SRT'),
      content: SizedBox(width: double.maxFinite, height: 320,
        child: SingleChildScrollView(child: SelectableText(output))),
      actions: [
        TextButton.icon(onPressed: () async {
          try {
            final ext = vtt ? 'vtt' : 'srt';
            final originalName = widget.filename;
            final dot = originalName.lastIndexOf('.');
            final baseName = dot > 0 ? originalName.substring(0, dot) : originalName;
            final result = await FilePicker.saveFile(
              dialogTitle: 'Ruaj titrat',
              fileName: '${baseName}_edited.$ext',
              bytes: Uint8List.fromList(utf8.encode(output)),
            );
            if (!mounted || !dialogContext.mounted) return;
            if (result != null) {
              Navigator.pop(dialogContext);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Skedari i titrave u ruajt.')));
            }
          } catch (_) {
            if (!mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Ruajtja dështoi. Provo Kopjo.')));
          }
        }, icon: const Icon(Icons.save_alt), label: const Text('Ruaj')),
        TextButton.icon(onPressed: () async {
          await Clipboard.setData(ClipboardData(text: output));
          if (!dialogContext.mounted || !mounted) return;
          Navigator.pop(dialogContext);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Titrat u kopjuan.')));
        }, icon: const Icon(Icons.copy), label: const Text('Kopjo')),
        TextButton(onPressed: () => Navigator.pop(dialogContext),
          child: const Text('Mbyll')),
      ],
    ));
  }
  @override
  Widget build(BuildContext context) {
    final report = validateTimeline(editedCues);
    final visible = <int>[for (var i = 0; i < timedCues.length; i++) if ((!onlyProblems || report.overlapIndexes.contains(i) || report.emptyIndexes.contains(i)) && (searchQuery.isEmpty || timedCues[i].original.toLowerCase().contains(searchQuery) || translations[i].text.toLowerCase().contains(searchQuery))) i];
    return Scaffold(appBar: AppBar(title: Text(widget.filename), actions: [TextButton(onPressed: () => _showExport(false), child: const Text('SRT')), TextButton(onPressed: () => _showExport(true), child: const Text('VTT'))]), body: SafeArea(child: ListView.builder(padding: const EdgeInsets.all(18), itemCount: visible.length + 1, itemBuilder: (context, index) {
      if (index == 0) { return Column(children: [
        if (videoController != null && videoController!.value.isInitialized) ...[
          AspectRatio(aspectRatio: videoController!.value.aspectRatio, child: Stack(fit: StackFit.expand, children: [
            VideoPlayer(videoController!),
            ValueListenableBuilder<VideoPlayerValue>(valueListenable: videoController!, builder: (context, value, _) {
              final current = value.position;
              final matching = editedCues.where((cue) => cue.start <= current && cue.end > current).toList();
              if (matching.isEmpty) return const SizedBox.shrink();
              final cue = matching.first;
              final text = cue.translation.trim().isNotEmpty ? cue.translation : cue.original;
              if (text.trim().isEmpty) return const SizedBox.shrink();
              return Align(alignment: Alignment.bottomCenter, child: Padding(padding: const EdgeInsets.all(12), child: DecoratedBox(decoration: BoxDecoration(color: Colors.black87, borderRadius: BorderRadius.circular(8)), child: Padding(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7), child: Text(text, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w600))))));
            }),
          ])),
          VideoProgressIndicator(videoController!, allowScrubbing: true, padding: const EdgeInsets.symmetric(vertical: 12)),
          ValueListenableBuilder<VideoPlayerValue>(
            valueListenable: videoController!,
            builder: (context, value, _) {
              String clock(Duration d) => '${d.inHours.toString().padLeft(2, '0')}:${(d.inMinutes % 60).toString().padLeft(2, '0')}:${(d.inSeconds % 60).toString().padLeft(2, '0')}';
              Future<void> jump(int seconds) async {
                final target = value.position + Duration(seconds: seconds);
                final bounded = target < Duration.zero ? Duration.zero : (target > value.duration ? value.duration : target);
                await videoController!.seekTo(bounded);
              }
              return Row(children: [
                IconButton(tooltip: '5 sekonda prapa', onPressed: () => jump(-5), icon: const Icon(Icons.replay_5)),
                IconButton(tooltip: value.isPlaying ? 'Pauzo' : 'Luaj', onPressed: () async {
                  if (value.isPlaying) { await videoController!.pause(); }
                  else { if (value.position >= value.duration) await videoController!.seekTo(Duration.zero); await videoController!.play(); }
                }, icon: Icon(value.isPlaying ? Icons.pause_circle : Icons.play_circle)),
                PopupMenuButton<double>(
                  tooltip: 'Shpejtësia e videos',
                  initialValue: playbackSpeed,
                  onSelected: (speed) async {
                    await videoController?.setPlaybackSpeed(speed);
                    if (mounted) setState(() => playbackSpeed = speed);
                  },
                  itemBuilder: (_) => const [
                    PopupMenuItem<double>(value: 0.5, child: Text('0.5×')),
                    PopupMenuItem<double>(value: 0.75, child: Text('0.75×')),
                    PopupMenuItem<double>(value: 1.0, child: Text('1×')),
                    PopupMenuItem<double>(value: 1.25, child: Text('1.25×')),
                    PopupMenuItem<double>(value: 1.5, child: Text('1.5×')),
                  ],
                  child: Padding(padding: const EdgeInsets.symmetric(horizontal: 8), child: Text('$playbackSpeed×', style: const TextStyle(fontWeight: FontWeight.w700))),
                ),
                IconButton(tooltip: '5 sekonda përpara', onPressed: () => jump(5), icon: const Icon(Icons.forward_5)),
                Expanded(child: Text('${clock(value.position)} / ${clock(value.duration)}', textAlign: TextAlign.end, style: const TextStyle(fontSize: 12))),
              ]);
            },
          ),
        ] else if (videoLoading) const LinearProgressIndicator(),
        OutlinedButton.icon(onPressed: _pickVideo, icon: const Icon(Icons.video_library_outlined), label: Text(videoController == null ? 'Ngarko videon përkatëse' : 'Ndrysho videon')),
        _TimelineBanner(report: report, cueCount: timedCues.length), Row(children: [Expanded(child: TextField(controller: offsetMs, keyboardType: const TextInputType.numberWithOptions(signed: true), decoration: const InputDecoration(labelText: 'Zhvendos kohën (ms)', hintText: '1500 ose -500', border: OutlineInputBorder()))), const SizedBox(width: 8), FilledButton(onPressed: _shift, child: const Text('Zbato'))]), const SizedBox(height: 14), TextField(controller: cueSearch, onChanged: (value) => setState(() => searchQuery = value.trim().toLowerCase()), decoration: const InputDecoration(prefixIcon: Icon(Icons.search), labelText: 'Kërko në titra', border: OutlineInputBorder())), SwitchListTile(title: const Text('Shfaq vetëm problemet e timeline-it'), value: onlyProblems, onChanged: (value) => setState(() => onlyProblems = value)), Row(children: [Expanded(child: Text('${visible.length} nga ${timedCues.length} titra', style: const TextStyle(color: Color(0xFF9EABBC)))), FilledButton.icon(onPressed: _addCue, icon: const Icon(Icons.add), label: const Text('Shto titër'))]), const SizedBox(height: 16)]); }
      final cueIndex = visible[index - 1]; final cue = timedCues[cueIndex];
      String stamp(Duration value) => value.toString().split('.').first;
      final overlap = report.overlapIndexes.contains(cueIndex); final empty = report.emptyIndexes.contains(cueIndex);
      return Card(color: overlap || empty ? const Color(0xFF3A241D) : null, child: Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [Expanded(child: Text('${cueIndex + 1}  •  ${stamp(cue.start)} → ${stamp(cue.end)}', style: const TextStyle(color: Color(0xFFE8C170)))), IconButton(tooltip: 'Shko te ky titër në video', onPressed: videoController == null ? null : () async { await videoController!.seekTo(cue.start); await videoController!.play(); if (mounted) setState(() {}); }, icon: const Icon(Icons.play_arrow)), IconButton(tooltip: 'Fshi këtë titër', onPressed: () => _deleteCue(cueIndex), icon: const Icon(Icons.delete_outline))]),
        if (overlap || empty) Padding(padding: const EdgeInsets.only(top: 6), child: Text([if (overlap) 'Mbivendosje kohe', if (empty) 'Cue bosh'].join(' • '), style: const TextStyle(color: Color(0xFFFFB49D), fontWeight: FontWeight.w700))),
        if (videoController != null) Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Wrap(spacing: 8, children: [
            OutlinedButton.icon(onPressed: () => _markCueBoundary(cueIndex, start: true),
              icon: const Icon(Icons.first_page), label: const Text('Fillimi = video')),
            OutlinedButton.icon(onPressed: () => _markCueBoundary(cueIndex, start: false),
              icon: const Icon(Icons.last_page), label: const Text('Fundi = video')),
          ]),
        ),
        const SizedBox(height: 8), SelectableText(cue.original, style: const TextStyle(fontSize: 17)), const SizedBox(height: 8),
        Align(alignment: Alignment.centerRight, child: TextButton.icon(
          onPressed: () { translations[cueIndex].text = cue.original; setState(() {}); },
          icon: const Icon(Icons.content_copy_outlined, size: 17),
          label: const Text('Kopjo origjinalin në redaktim'),
        )),
        const SizedBox(height: 8),
        TextField(controller: translations[cueIndex], maxLines: null, decoration: const InputDecoration(labelText: 'Teksti i redaktuar / përkthimi shqip', border: OutlineInputBorder())),
      ])));
    })));
  }
}

class _TimelineBanner extends StatelessWidget {
  const _TimelineBanner({required this.report, required this.cueCount});
  final SubtitleTimelineReport report; final int cueCount;
  @override Widget build(BuildContext context) => Container(margin: const EdgeInsets.only(bottom: 14), padding: const EdgeInsets.all(14), decoration: BoxDecoration(color: report.isClean ? const Color(0xFF102B27) : const Color(0xFF38271E), borderRadius: BorderRadius.circular(16)), child: Row(children: [Icon(report.isClean ? Icons.verified_outlined : Icons.warning_amber_rounded, color: const Color(0xFFE8C170)), const SizedBox(width: 10), Expanded(child: Text(report.isClean ? 'Timeline i pastër • $cueCount cue' : '${report.overlapIndexes.length} mbivendosje • ${report.emptyIndexes.length} cue bosh', style: const TextStyle(fontWeight: FontWeight.w700)))]));
}
