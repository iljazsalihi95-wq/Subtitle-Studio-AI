import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';

// Session-only credentials entered by the owner. Never compiled or written to disk.
String _endpoint = '';
String _sessionToken = '';
String _targetLanguage = 'sq';

Future<bool> configureAi(BuildContext context) async {
  final url = TextEditingController(text: _endpoint);
  final token = TextEditingController(text: _sessionToken);
  var language = _targetLanguage;
  final result = await showDialog<bool>(context: context, builder: (dialog) => StatefulBuilder(builder: (dialog, update) => AlertDialog(
    title: const Text('Lidhja private AI'),
    content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
      TextField(controller: url, decoration: const InputDecoration(labelText: 'Adresa HTTPS e Worker-it')),
      TextField(controller: token, obscureText: true, enableSuggestions: false, autocorrect: false, decoration: const InputDecoration(labelText: 'Token privat i aksesit (jo OpenAI key)')),
      DropdownButton<String>(value: language, isExpanded: true, items: const [DropdownMenuItem(value: 'sq', child: Text('Shqip')), DropdownMenuItem(value: 'de', child: Text('Deutsch')), DropdownMenuItem(value: 'en', child: Text('English')), DropdownMenuItem(value: 'tr', child: Text('Türkçe')), DropdownMenuItem(value: 'ar', child: Text('العربية'))], onChanged: (v) => update(() => language = v!)),
      const Text('Tokeni mbahet vetëm gjatë kësaj seance. Teksti i zgjedhur dërgohet te shërbimi AI.'),
    ])),
    actions: [TextButton(onPressed: () => Navigator.pop(dialog, false), child: const Text('Anulo')), FilledButton(onPressed: () {
      final uri = Uri.tryParse(url.text.trim());
      if (uri == null || uri.scheme != 'https' || uri.host.isEmpty || uri.userInfo.isNotEmpty || token.text.trim().length < 32 || token.text.trim().startsWith('sk-')) return;
      _endpoint = url.text.trim().replaceAll(RegExp(r'/+$'), ''); _sessionToken = token.text.trim(); _targetLanguage = language;
      Navigator.pop(dialog, true);
    }, child: const Text('Lidh'))],
  )));
  // Controllers remain valid until the dialog's exit animation has completed.
  await Future<void>.delayed(const Duration(milliseconds: 300));
  url.dispose(); token.dispose();
  return result == true;
}

Future<String> aiText(String text, {String operation = 'explain', String path = '/v1/text'}) async {
  if (text.trim().isEmpty || text.length > 6000) throw const FormatException('Zgjidh 1–6000 shkronja për AI.');
  final client = HttpClient()..connectionTimeout = const Duration(seconds: 15);
  try {
    final request = await client.postUrl(Uri.parse('$_endpoint$path')).timeout(const Duration(seconds: 15));
    request.followRedirects = false;
    request.headers.contentType = ContentType.json;
    request.headers.set(HttpHeaders.authorizationHeader, 'Bearer $_sessionToken');
    request.write(jsonEncode({'text': text, 'sceneText': text, 'operation': operation, 'targetLanguage': _targetLanguage}));
    final response = await request.close().timeout(const Duration(seconds: 35));
    final body = await response.transform(utf8.decoder).join().timeout(const Duration(seconds: 35));
    if (response.statusCode == 401) throw const FormatException('Tokeni privat nuk u pranua.');
    if (response.statusCode != 200) throw FormatException('Shërbimi AI u përgjigj me kodin ${response.statusCode}.');
    final data = jsonDecode(body);
    if (data is! Map || (data['text'] ?? data['plan']) is! String) throw const FormatException('Përgjigje AI e pavlefshme.');
    return (data['text'] ?? data['plan']) as String;
  } finally { client.close(force: true); }
}
