import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:skillup/login_page.dart';

void main() {
  testWidgets('Forgot password button shows SnackBar', (WidgetTester tester) async {
    // Build the LoginPage widget
    await tester.pumpWidget(
      const MaterialApp(
        home: LoginPage(),
      ),
    );

    // Verify that the "Forgot password?" text is present
    expect(find.text('Forgot password?'), findsOneWidget);

    // Find and tap the forgot password button
    await tester.tap(find.text('Forgot password?'));
    
    // Pump to allow the SnackBar to appear
    await tester.pump();

    // Verify that SnackBar is shown with expected message
    expect(find.byType(SnackBar), findsOneWidget);
    expect(find.text('Password reset feature coming soon'), findsOneWidget);
  });
}