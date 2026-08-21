import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wpl_cricket_app/main.dart';

void main() {
  testWidgets('WPL Cricket App basic smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: WplCricketApp(),
      ),
    );
    await tester.pumpAndSettle();

    // Verify top fixtures title appears
    expect(find.text('MATCHES & FIXTURES'), findsOneWidget);
  });
}
