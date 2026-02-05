import 'package:flutter_test/flutter_test.dart';
import 'package:ukotka_hot_corners/main.dart';

void main() {
  testWidgets('App smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const UKotkaHotCornersApp());
    
    // Verify that we are on the settings screen or at least the app builds
    expect(find.byType(UKotkaHotCornersApp), findsOneWidget);
  });
}
