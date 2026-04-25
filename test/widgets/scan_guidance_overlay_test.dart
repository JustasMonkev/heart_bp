import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:heart_bp/src/widgets/scan_guidance_overlay.dart';

void main() {
  testWidgets('renders capture guidance chips', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: SizedBox.expand(child: ScanGuidanceOverlay())),
      ),
    );

    expect(find.text('Fill frame'), findsOneWidget);
    expect(find.text('No glare'), findsOneWidget);
    expect(find.text('Multi-frame'), findsOneWidget);
    expect(find.byIcon(Icons.fit_screen_rounded), findsOneWidget);
  });
}
