import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:mvcs/core/session/auth_controller.dart';
import 'package:mvcs/features/auth/screens/login_screen.dart';

void main() {
  testWidgets('login screen renders', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(preferences),
        ],
        child: const MaterialApp(home: LoginScreen()),
      ),
    );

    expect(find.text('MVCS'), findsOneWidget);
    expect(find.text('Login'), findsOneWidget);
  });
}
