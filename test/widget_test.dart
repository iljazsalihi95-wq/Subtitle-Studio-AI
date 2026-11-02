import 'package:flutter_test/flutter_test.dart';
import 'package:subtitle_studio_ai/main.dart';

void main() {
  testWidgets('Home opens and inactive studio card explains status', (tester) async {
    await tester.pumpWidget(const StudioApp());
    expect(find.byType(HomePage), findsOneWidget);
    expect(find.text('Projekt i ri'), findsOneWidget);
    await tester.tap(find.text('Studio e titrave'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Ky modul është në zhvillim'), findsOneWidget);
    await tester.tap(find.text('Mbyll'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Ky modul është në zhvillim'), findsNothing);
  });
}
