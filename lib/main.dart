import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
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
  @override State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  String? selectedFile;
  int tab = 0;

  Future<void> _pick(List<String> extensions) async {
    final result = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: extensions, withData: true);
    if (!mounted || result == null || result.files.isEmpty) return;
    final file = result.files.single;
    setState(() => selectedFile = file.name);
    if (['srt', 'vtt'].contains(file.extension?.toLowerCase())) {
      final bytes = file.bytes;
      if (bytes == null) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Skedari nuk mund të lexohet.')));
        return;
      }
      final cues = parseSubtitles(utf8.decode(bytes, allowMalformed: true));
      if (mounted) await Navigator.push(context, MaterialPageRoute<void>(builder: (_) => SubtitlePreviewPage(filename: file.name, cues: cues)));
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Videoja u zgjodh: ${file.name}. Transkriptimi AI lidhet vetëm përmes backend-it privat.')));
    }
  }

  Widget _home() => ListView(padding: const EdgeInsets.fromLTRB(20,18,20,28), children: [
    const _Brand(), const SizedBox(height:28),
    Text('Studio profesionale për titrat e tu.', style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight:FontWeight.w800)),
    const SizedBox(height:8), const Text('Importo • kontrollo timeline-in • përkthe • eksporto', style:TextStyle(color:Color(0xFFB7C2D0))), const SizedBox(height:24),
    _Action(icon:Icons.video_file_outlined,title:'Projekt i ri',subtitle:selectedFile ?? 'Video • SRT • VTT',primary:true,onTap:()=>_pick(['mp4','mkv','mov','webm','srt','vtt'])),
    _Action(icon:Icons.subtitles_outlined,title:'Studio e titrave',subtitle:'Hap SRT/VTT • timeline • editor',onTap:()=>_pick(['srt','vtt'])),
    _Action(icon:Icons.translate,title:'Përkthimi AI',subtitle:'Shqip • ruaj timecode-et',onTap:()=>setState(()=>tab=2)),
    _Action(icon:Icons.folder_open_outlined,title:'Projektet',subtitle:selectedFile ?? 'Asnjë projekt i hapur',onTap:()=>setState(()=>tab=3)),
    const SizedBox(height:18), const _Status(),
  ]);

  Widget _module(String title, String subtitle, IconData icon, List<Widget> children) => ListView(padding:const EdgeInsets.all(20), children:[
    const _Brand(), const SizedBox(height:28), Icon(icon,size:56,color:const Color(0xFFE8C170)), const SizedBox(height:16), Text(title,style:Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight:FontWeight.w800)), const SizedBox(height:8), Text(subtitle,style:const TextStyle(color:Color(0xFFB7C2D0))), const SizedBox(height:24), ...children]);

  @override Widget build(BuildContext context) {
    final pages=<Widget>[
      _home(),
      _module('Studio e titrave','Editor lokal SRT/VTT me kontroll timeline.',Icons.subtitles_outlined,[_Action(icon:Icons.file_open_outlined,title:'Hap titrat',subtitle:'SRT • VTT',primary:true,onTap:()=>_pick(['srt','vtt']))]),
      _module('Përkthimi AI','AI përdoret vetëm përmes backend-it privat; asnjë API key nuk futet në APK.',Icons.auto_awesome_outlined,[const _Status()]),
      _module('Projektet','Vazhdo me skedarin e fundit të zgjedhur.',Icons.folder_outlined,[_Action(icon:Icons.history,title:selectedFile ?? 'Asnjë projekt i hapur',subtitle:selectedFile==null?'Zgjidh një projekt nga Ballina':'Skedari aktual',onTap:selectedFile==null?()=>setState(()=>tab=0):null)]),
    ];
    return Scaffold(body:SafeArea(child:pages[tab]),bottomNavigationBar:NavigationBar(selectedIndex:tab,onDestinationSelected:(i)=>setState(()=>tab=i),destinations:const[
      NavigationDestination(icon:Icon(Icons.home_outlined),selectedIcon:Icon(Icons.home),label:'Ballina'), NavigationDestination(icon:Icon(Icons.subtitles_outlined),label:'Studio'), NavigationDestination(icon:Icon(Icons.auto_awesome_outlined),label:'AI'), NavigationDestination(icon:Icon(Icons.folder_outlined),label:'Projektet') ]));
  }
}

class _Brand extends StatelessWidget { const _Brand(); @override Widget build(BuildContext context)=>const Row(children:[_Mark(),SizedBox(width:14),Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text('SUBTITLE STUDIO AI',style:TextStyle(fontWeight:FontWeight.w900,letterSpacing:1.4,fontSize:17)),SizedBox(height:3),Text('CREATE • TRANSLATE • SYNC',style:TextStyle(color:Color(0xFFE8C170),fontSize:11,letterSpacing:1.1))]))]); }
class _Mark extends StatelessWidget { const _Mark(); @override Widget build(BuildContext context)=>Container(width:58,height:58,decoration:BoxDecoration(borderRadius:BorderRadius.circular(16),gradient:const LinearGradient(colors:[Color(0xFF263A55),Color(0xFF101D30)]),border:Border.all(color:const Color(0xFFE8C170))),child:const Stack(alignment:Alignment.center,children:[Icon(Icons.movie_filter_outlined,color:Color(0xFFE8C170),size:34),Positioned(bottom:8,child:Text('CC',style:TextStyle(fontSize:9,fontWeight:FontWeight.w900)))])); }
class _Action extends StatelessWidget { const _Action({required this.icon,required this.title,required this.subtitle,this.primary=false,this.onTap}); final IconData icon; final String title,subtitle; final bool primary; final VoidCallback? onTap; @override Widget build(BuildContext context)=>Padding(padding:const EdgeInsets.only(bottom:12),child:Material(color:primary?const Color(0xFF182A42):const Color(0xFF101C2C),shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(18),side:BorderSide(color:primary?const Color(0xFFE8C170):const Color(0xFF26364B))),clipBehavior:Clip.antiAlias,child:ListTile(onTap:onTap,contentPadding:const EdgeInsets.symmetric(horizontal:18,vertical:8),leading:Icon(icon,color:const Color(0xFFE8C170)),title:Text(title,style:const TextStyle(fontWeight:FontWeight.w700)),subtitle:Text(subtitle,style:const TextStyle(color:Color(0xFF9EABBC))),trailing:onTap==null?null:const Icon(Icons.chevron_right,color:Color(0xFFE8C170))))); }
class _Status extends StatelessWidget { const _Status(); @override Widget build(BuildContext context)=>const Row(children:[Icon(Icons.shield_outlined,size:17,color:Color(0xFF7F91A8)),SizedBox(width:8),Expanded(child:Text('Skedarët lokalë • pa API keys në APK',style:TextStyle(color:Color(0xFF7F91A8),fontSize:12)))]); }

class SubtitlePreviewPage extends StatefulWidget { const SubtitlePreviewPage({super.key,required this.filename,required this.cues}); final String filename; final List<SubtitleCue> cues; @override State<SubtitlePreviewPage> createState()=>_SubtitlePreviewPageState(); }
class _SubtitlePreviewPageState extends State<SubtitlePreviewPage> {
 late final List<TextEditingController> translations;
 @override void initState(){super.initState();translations=widget.cues.map((c)=>TextEditingController(text:c.translation)).toList();}
 @override void dispose(){for(final c in translations){c.dispose();}super.dispose();}
 List<SubtitleCue> get editedCues=>[for(var i=0;i<widget.cues.length;i++)widget.cues[i].translated(translations[i].text)];
 void _export(bool vtt){final output=vtt?exportVtt(editedCues):exportSrt(editedCues);showDialog<void>(context:context,builder:(c)=>AlertDialog(title:Text(vtt?'Eksport VTT':'Eksport SRT'),content:SizedBox(width:double.maxFinite,height:320,child:SingleChildScrollView(child:SelectableText(output))),actions:[TextButton(onPressed:()=>Navigator.pop(c),child:const Text('Mbyll'))]));}
 @override Widget build(BuildContext context){final report=validateTimeline(editedCues);return Scaffold(appBar:AppBar(title:Text(widget.filename),actions:[TextButton(onPressed:()=>_export(false),child:const Text('SRT')),TextButton(onPressed:()=>_export(true),child:const Text('VTT'))]),body:SafeArea(child:ListView.builder(padding:const EdgeInsets.all(18),itemCount:widget.cues.length+1,itemBuilder:(context,index){if(index==0)return _TimelineBanner(report:report,cueCount:widget.cues.length);final i=index-1;final cue=widget.cues[i];final overlap=report.overlapIndexes.contains(i),empty=report.emptyIndexes.contains(i);return Card(color:overlap||empty?const Color(0xFF3A241D):null,child:Padding(padding:const EdgeInsets.all(16),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text('${i+1} • ${cue.start} → ${cue.end}',style:const TextStyle(color:Color(0xFFE8C170))),if(overlap||empty)Text([if(overlap)'Mbivendosje kohe',if(empty)'Cue bosh'].join(' • ')),const SizedBox(height:8),SelectableText(cue.original),const SizedBox(height:12),TextField(controller:translations[i],onChanged:(_)=>setState((){}),maxLines:null,decoration:const InputDecoration(labelText:'Përkthimi shqip',border:OutlineInputBorder()))])));}))));}
}
class _TimelineBanner extends StatelessWidget { const _TimelineBanner({required this.report,required this.cueCount}); final SubtitleTimelineReport report; final int cueCount; @override Widget build(BuildContext context)=>Container(margin:const EdgeInsets.only(bottom:14),padding:const EdgeInsets.all(14),decoration:BoxDecoration(color:report.isClean?const Color(0xFF102B27):const Color(0xFF38271E),borderRadius:BorderRadius.circular(16)),child:Text(report.isClean?'Timeline i pastër • $cueCount cue':'${report.overlapIndexes.length} mbivendosje • ${report.emptyIndexes.length} cue bosh',style:const TextStyle(fontWeight:FontWeight.w700))); }
