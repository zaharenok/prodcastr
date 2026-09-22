import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:prodcastr/main.dart';

void main() {
  testWidgets('App renders', (WidgetTester tester) async {
    await tester.pumpWidget(const ProviderScope(child: ProdcastrApp()));
    expect(find.text('🚀 Prodcastr'), findsOneWidget);
  });
}
