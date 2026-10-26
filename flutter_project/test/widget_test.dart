import 'package:flutter_test/flutter_test.dart';
import 'package:quickbus_sg/main.dart';
import 'package:quickbus_sg/services/favorites_service.dart';

void main() {
  testWidgets('QuickBus SG app smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(
      const QuickBusApp(initialSettings: UserSettings()),
    );
    expect(find.text('QuickBus SG'), findsOneWidget);
  });
}
