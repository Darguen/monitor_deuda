import 'dart:async';

import 'package:appwrite/models.dart' as models;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:monitor_deuda/core/router/app_router.dart';
import 'package:monitor_deuda/features/auth/presentation/auth_controller.dart';
import 'package:monitor_deuda/features/auth/presentation/login_screen.dart';
import 'package:monitor_deuda/features/auth/presentation/register_screen.dart';
import 'package:monitor_deuda/features/groups/data/groups_repository.dart';
import 'package:monitor_deuda/features/home/home_screen.dart';

import '../../helpers/app_harness.dart';
import '../../helpers/fixtures.dart';

void main() {
  late MockGroupsRepository groups;

  setUp(() {
    groups = MockGroupsRepository();
    when(() => groups.listGroups()).thenAnswer((_) async => []);
  });

  Future<ProviderContainer> pumpApp(
    WidgetTester tester,
    Future<models.User?> auth,
  ) async {
    final container = ProviderContainer(overrides: [
      authControllerProvider.overrideWith(() => FakeAuthController(auth)),
      groupsRepositoryProvider.overrideWithValue(groups),
    ]);
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: Consumer(
          builder: (context, ref, _) =>
              MaterialApp.router(routerConfig: ref.watch(routerProvider)),
        ),
      ),
    );
    await tester.pump();
    return container;
  }

  testWidgets('mientras carga la sesión muestra el splash', (tester) async {
    final completer = Completer<models.User?>();
    await pumpApp(tester, completer.future);

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.byType(LoginScreen), findsNothing);
    expect(find.byType(HomeScreen), findsNothing);
  });

  testWidgets('sin sesión redirige a login', (tester) async {
    await pumpApp(tester, Future.value(null));
    await tester.pumpAndSettle();

    expect(find.byType(LoginScreen), findsOneWidget);
  });

  testWidgets('con sesión redirige a home', (tester) async {
    await pumpApp(tester, Future.value(makeUser()));
    await tester.pumpAndSettle();

    expect(find.byType(HomeScreen), findsOneWidget);
  });

  testWidgets('sin sesión se puede entrar a register', (tester) async {
    await pumpApp(tester, Future.value(null));
    await tester.pumpAndSettle();

    await tester.tap(find.text('¿No tienes cuenta? Regístrate'));
    await tester.pumpAndSettle();

    expect(find.byType(RegisterScreen), findsOneWidget);
  });

  testWidgets('al iniciar sesión sale de login hacia home', (tester) async {
    final container = await pumpApp(tester, Future.value(null));
    await tester.pumpAndSettle();
    expect(find.byType(LoginScreen), findsOneWidget);

    (container.read(authControllerProvider.notifier) as FakeAuthController)
        .emit(makeUser());
    await tester.pumpAndSettle();

    expect(find.byType(HomeScreen), findsOneWidget);
  });

  testWidgets('al cerrar sesión vuelve a login', (tester) async {
    final container = await pumpApp(tester, Future.value(makeUser()));
    await tester.pumpAndSettle();
    expect(find.byType(HomeScreen), findsOneWidget);

    (container.read(authControllerProvider.notifier) as FakeAuthController)
        .emit(null);
    await tester.pumpAndSettle();

    expect(find.byType(LoginScreen), findsOneWidget);
  });
}
