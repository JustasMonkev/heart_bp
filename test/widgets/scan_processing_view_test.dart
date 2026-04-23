import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:heart_bp/src/services/blood_pressure_tips.dart';
import 'package:heart_bp/src/widgets/scan_processing_view.dart';

void main() {
  testWidgets('renders a progress bar and a health tip', (tester) async {
    final tip = BloodPressureTips.tipForSeed(1);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: ScanProcessingView(tip: tip)),
      ),
    );

    expect(find.text('Analyzing your reading'), findsOneWidget);
    expect(find.byType(LinearProgressIndicator), findsOneWidget);
    expect(find.text('Health tip'), findsOneWidget);
    expect(find.text(tip.title), findsOneWidget);
    expect(find.text(tip.message), findsOneWidget);
  });
}
