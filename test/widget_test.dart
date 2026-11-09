import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:aether_weather/app.dart';
import 'package:aether_weather/main.dart';

void main() {
  testWidgets('ATMOS launches its weather application shell', (tester) async {
    SharedPreferences.setMockInitialValues({});

    await tester.pumpWidget(const AtmosApp(home: WeatherShell()));
    await tester.pump();

    expect(find.text('ATMOS'), findsOneWidget);
    expect(find.text('WEATHER'), findsOneWidget);
  });
}
