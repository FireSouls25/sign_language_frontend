import 'package:flutter_test/flutter_test.dart';
import 'package:sign_frontend/main.dart';

void main() {
  testWidgets('App renders without crashing', (WidgetTester tester) async {
    await tester.pumpWidget(const LSCTranslatorApp());
    expect(find.text('LSC Translator'), findsAny);
  });
}
