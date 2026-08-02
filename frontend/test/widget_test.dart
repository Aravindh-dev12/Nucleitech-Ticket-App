import 'package:flutter_test/flutter_test.dart';
import 'package:nuclei_tech_scada_ticketing/main.dart';

void main() {
  testWidgets('shows the sign-in screen', (tester) async {
    await tester.pumpWidget(const NucleiTechApp(authenticated: false));

    expect(find.text('Sign in'), findsOneWidget);
    expect(find.text('Email address'), findsOneWidget);
  });
}
