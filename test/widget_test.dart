import 'package:flutter_test/flutter_test.dart';
import 'package:subtitle_studio_ai/main.dart';

void main() {
  testWidgets('App opens', (tester) async {
    await tester.pumpWidget(const StudioApp());
    expect(find.byType(HomePage), findsOneWidget);
  });
}
