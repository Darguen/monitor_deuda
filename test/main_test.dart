import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:monitor_deuda/features/auth/data/auth_repository.dart';
import 'package:monitor_deuda/features/auth/presentation/login_screen.dart';
import 'package:monitor_deuda/main.dart';

import 'helpers/app_harness.dart';

void main() {
  testWidgets('MyApp arranca en login cuando no hay sesión', (tester) async {
    final repo = MockAuthRepository();
    when(() => repo.currentUser()).thenAnswer((_) async => null);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [authRepositoryProvider.overrideWithValue(repo)],
        child: const MyApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(LoginScreen), findsOneWidget);
  });

  testWidgets('MyApp usa el título y el tema Material 3', (tester) async {
    final repo = MockAuthRepository();
    when(() => repo.currentUser()).thenAnswer((_) async => null);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [authRepositoryProvider.overrideWithValue(repo)],
        child: const MyApp(),
      ),
    );
    await tester.pumpAndSettle();

    final app = tester.widget<MaterialApp>(find.byType(MaterialApp));
    expect(app.title, 'Monitor Deuda App');
    expect(app.theme!.useMaterial3, isTrue);
  });
}
