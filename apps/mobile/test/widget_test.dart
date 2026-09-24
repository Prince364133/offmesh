import 'package:flutter_test/flutter_test.dart';
import 'package:offmesh/main.dart';

void main() {
  testWidgets('OffMeshApp navigation smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const OffMeshApp());
    expect(find.text('Chats'), findsWidgets);
    expect(find.text('People'), findsOneWidget);
    expect(find.text('Nearby'), findsOneWidget);
    expect(find.text('Settings'), findsOneWidget);
  });
}
