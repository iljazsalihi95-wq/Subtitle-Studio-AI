import 'package:flutter/material.dart';
void main() => runApp(const StudioApp());
class StudioApp extends StatelessWidget {
  const StudioApp({super.key});
  @override
  Widget build(BuildContext context) {
    const gold = Color(0xFFE5BB69);
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Subtitle Studio AI',
      theme: ThemeData(brightness: Brightness.dark, scaffoldBackgroundColor: const Color(0xFF0C1728), colorScheme: ColorScheme.fromSeed(seedColor: gold, brightness: Brightness.dark), useMaterial3: true),
      home: const HomePage(),
    );
  }
}
class HomePage extends StatelessWidget {
  const HomePage({super.key});
  @override
  Widget build(BuildContext context) {
    const gold = Color(0xFFE5BB69);
    return Scaffold(
      appBar: AppBar(title: const Text('Subtitle Studio AI'), backgroundColor: Colors.transparent),
      body: SafeArea(child: ListView(padding: const EdgeInsets.all(20), children: [
        const Icon(Icons.movie_creation_outlined, size: 84, color: gold),
        const SizedBox(height: 20),
        Text('Studio profesionale e titrave', textAlign: TextAlign.center, style: Theme.of(context).textTheme.headlineMedium),
        const SizedBox(height: 12),
        const Text('Transkriptim • Përkthim • SRT', textAlign: TextAlign.center),
        const SizedBox(height: 30),
        const _FeatureTile(icon: Icons.link, title: 'Importo video', subtitle: 'URL dhe skedarë të autorizuar'),
        const _FeatureTile(icon: Icons.subtitles, title: 'Redaktori SRT', subtitle: 'Dialogu origjinal dhe përkthimi shqip'),
        const _FeatureTile(icon: Icons.download, title: 'Eksporto titrat', subtitle: 'SRT / VTT'),
        const SizedBox(height: 20),
        const Text('Versioni 0.1 — ndërfaqe fillestare; funksionet AI nuk janë lidhur ende.', textAlign: TextAlign.center, style: TextStyle(color: Colors.white54)),
      ])),
    );
  }
}
class _FeatureTile extends StatelessWidget {
  const _FeatureTile({required this.icon, required this.title, required this.subtitle});
  final IconData icon;
  final String title;
  final String subtitle;
  @override
  Widget build(BuildContext context) => Card(
    color: const Color(0xFF17263B),
    margin: const EdgeInsets.symmetric(vertical: 7),
    child: ListTile(leading: Icon(icon, color: const Color(0xFFE5BB69)), title: Text(title), subtitle: Text(subtitle)),
  );
}
