import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wpl_cricket_app/main.dart';

void main() {
  testWidgets('PitchPe App basic smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: PitchPeApp(),
      ),
    );
    await tester.pumpAndSettle();

    // Verify active tournament chip and navigation tabs appear
    expect(find.text('WPL 2026'), findsOneWidget);
    expect(find.text('Fixtures'), findsOneWidget);
    expect(find.text('Standings'), findsOneWidget);
  });
}
