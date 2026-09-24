import 'package:flutter_test/flutter_test.dart';
import 'package:nearlink_mobile/main.dart';

void main() {
  testWidgets('NearLinkApp smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const NearLinkApp());
    expect(find.text('Mesh Radar'), findsOneWidget);
    expect(find.text('Radar'), findsOneWidget);
    expect(find.text('Messages'), findsOneWidget);
    expect(find.text('My Card'), findsOneWidget);
    expect(find.text('Gateway'), findsOneWidget);
  });
}
