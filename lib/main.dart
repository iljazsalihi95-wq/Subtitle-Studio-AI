import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'features/subtitles/srt_editor.dart';
import 'package:flutter/material.dart';

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

  Future<void> _import() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['mp4', 'mkv', 'mov', 'webm', 'srt', 'vtt'],
        withData: true,
      );
      if (!mounted || result == null || result.files.isEmpty) return;
      final file = result.files.single;
      setState(() => selectedFile = file.name);
      if (['srt', 'vtt'].contains(file.extension?.toLowerCase()) && file.bytes != null) {
        final cues = parseSubtitles(utf8.decode(file.bytes!, allowMalformed: true));
        if (!mounted) return;
        await Navigator.push(context, MaterialPageRoute<void>(
          builder: (_) => _SubtitlePreviewPage(filename: file.name, cues: cues),
        ));
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Skedari u zgjodh: $selectedFile. Importi i videos është në zhvillim.')),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Skedari nuk mund të zgjidhej. Provo përsëri.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
            children: [
              const _Brand(),
              const SizedBox(height: 28),
              Text('Ktheje videon në titra të saktë.', style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              const Text('Importo materialin e autorizuar dhe puno lokalisht. AI cloud lidhet vetëm më vonë.', style: TextStyle(color: Color(0xFFB7C2D0), height: 1.45)),
              const SizedBox(height: 24),
              _Action(icon: Icons.video_file_outlined, title: 'Projekt i ri', subtitle: selectedFile ?? 'Importo video ose SRT/VTT', primary: true, onTap: _import),
              const _Action(icon: Icons.subtitles_outlined, title: 'Studio e titrave', subtitle: 'Timeline • tekst origjinal • shqip'),
              const _Action(icon: Icons.translate, title: 'Përkthimi', subtitle: 'Rishiko përkthimin pa ndryshuar kohët'),
              const _Action(icon: Icons.ios_share_outlined, title: 'Eksporto', subtitle: 'SRT dhe VTT'),
              const SizedBox(height: 18),
              const _Status(),
            ],
          ),
        ),
      );
}

class _Brand extends StatelessWidget {
  const _Brand();
  @override
  Widget build(BuildContext context) => const Row(children: [
        _Mark(), SizedBox(width: 14),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('SUBTITLE STUDIO', style: TextStyle(fontWeight: FontWeight.w800, letterSpacing: 1.6, fontSize: 17)),
          SizedBox(height: 3), Text('AI • PRIVATE STUDIO', style: TextStyle(color: Color(0xFFE8C170), fontSize: 11, letterSpacing: 1.2)),
        ])),
      ]);
}

class _Mark extends StatelessWidget {
  const _Mark();
  @override
  Widget build(BuildContext context) => Container(
        width: 58, height: 58,
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(16), gradient: const LinearGradient(colors: [Color(0xFF263A55), Color(0xFF101D30)]), border: Border.all(color: const Color(0xFFE8C170), width: 1.2)),
        child: const Stack(alignment: Alignment.center, children: [Icon(Icons.movie_filter_outlined, color: Color(0xFFE8C170), size: 34), Positioned(bottom: 8, child: Text('CC', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900)))]),
      );
}

class _Action extends StatelessWidget {
  const _Action({required this.icon, required this.title, required this.subtitle, this.primary = false, this.onTap});
  final IconData icon; final String title, subtitle; final bool primary; final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Material(
          color: primary ? const Color(0xFF182A42) : const Color(0xFF101C2C),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18), side: BorderSide(color: primary ? const Color(0xFFE8C170).withValues(alpha: .65) : const Color(0xFF26364B))),
          clipBehavior: Clip.antiAlias,
          child: ListTile(
            onTap: onTap ?? () => _showStatus(context),
            contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
            leading: Container(width: 44, height: 44, decoration: BoxDecoration(color: const Color(0xFFE8C170).withValues(alpha: .10), borderRadius: BorderRadius.circular(13)), child: Icon(icon, color: const Color(0xFFE8C170))),
            title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
            subtitle: Text(subtitle, style: const TextStyle(color: Color(0xFF9EABBC))),
            trailing: const Icon(Icons.chevron_right, color: Color(0xFFE8C170)),
          ),
        ),
      );
  void _showStatus(BuildContext context) => showModalBottomSheet<void>(context: context, showDragHandle: true, builder: (c) => SafeArea(child: Padding(padding: const EdgeInsets.all(24), child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: Theme.of(context).textTheme.headlineSmall), const SizedBox(height: 12), Text(subtitle), const SizedBox(height: 18), const Text('Ky modul është në zhvillim.', style: TextStyle(color: Colors.grey)), const SizedBox(height: 18), FilledButton(onPressed: () => Navigator.pop(c), child: const Text('Mbyll'))]))));
}

class _Status extends StatelessWidget {
  const _Status();
  @override
  Widget build(BuildContext context) => const Row(children: [Icon(Icons.shield_outlined, size: 17, color: Color(0xFF7F91A8)), SizedBox(width: 8), Expanded(child: Text('Import lokal • pa kredenciale në aplikacion', style: TextStyle(color: Color(0xFF7F91A8), fontSize: 12)))]);
}

class _SubtitlePreviewPage extends StatelessWidget {
  const _SubtitlePreviewPage({required this.filename, required this.cues});
  final String filename;
  final List<SubtitleCue> cues;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(filename)),
    body: SafeArea(child: ListView.builder(
      padding: const EdgeInsets.all(18),
      itemCount: cues.length,
      itemBuilder: (context, index) {
        final cue = cues[index];
        String stamp(Duration value) => value.toString().split('.').first;
        return Card(child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('${index + 1}  •  ${stamp(cue.start)} → ${stamp(cue.end)}',
              style: const TextStyle(color: Color(0xFFE8C170))),
            const SizedBox(height: 8),
            SelectableText(cue.original, style: const TextStyle(fontSize: 17)),
          ]),
        ));
      },
    )),
  );
}
