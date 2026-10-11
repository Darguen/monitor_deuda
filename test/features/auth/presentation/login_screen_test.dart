import 'package:appwrite/appwrite.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:monitor_deuda/features/auth/presentation/login_screen.dart';

import '../../../helpers/app_harness.dart';
import '../../../helpers/fixtures.dart';

void main() {
  late MockAuthRepository repo;

  setUp(() {
    repo = MockAuthRepository();
    when(() => repo.currentUser()).thenAnswer((_) async => null);
  });

  Future<void> pump(WidgetTester tester) =>
      pumpScreen(tester, const LoginScreen(), overrides: authOverrides(repo));

  Future<void> fill(WidgetTester tester, String email, String password) async {
    await tester.enterText(find.widgetWithText(TextFormField, 'Correo'), email);
    await tester.enterText(
        find.widgetWithText(TextFormField, 'Contraseña'), password);
  }

  testWidgets('muestra título, campos y botón', (tester) async {
    await pump(tester);
    expect(find.text('Monitor Deuda App'), findsOneWidget);
    expect(find.widgetWithText(TextFormField, 'Correo'), findsOneWidget);
    expect(find.widgetWithText(TextFormField, 'Contraseña'), findsOneWidget);
    expect(find.text('Iniciar sesión'), findsOneWidget);
  });

  testWidgets('campos vacíos muestran errores y no llaman al repositorio',
      (tester) async {
    await pump(tester);
    await tester.tap(find.text('Iniciar sesión'));
    await tester.pump();

    expect(find.text('Ingresa tu correo'), findsOneWidget);
    expect(find.text('Ingresa tu contraseña'), findsOneWidget);
    verifyNever(() => repo.login(
          email: any(named: 'email'),
          password: any(named: 'password'),
        ));
  });

  testWidgets('correo sin @ es inválido', (tester) async {
    await pump(tester);
    await fill(tester, 'correo-malo', 'secreto');
    await tester.tap(find.text('Iniciar sesión'));
    await tester.pump();

    expect(find.text('Correo inválido'), findsOneWidget);
  });

  testWidgets('envía correo recortado y contraseña tal cual', (tester) async {
    when(() => repo.login(
          email: any(named: 'email'),
          password: any(named: 'password'),
        )).thenAnswer((_) async => MockSession());
    await pump(tester);

    await fill(tester, '  ana@b.cl  ', ' clave ');
    await tester.tap(find.text('Iniciar sesión'));
    await tester.pumpAndSettle();

    verify(() => repo.login(email: 'ana@b.cl', password: ' clave ')).called(1);
  });

  testWidgets('muestra el mensaje de AppwriteException', (tester) async {
    when(() => repo.login(
          email: any(named: 'email'),
          password: any(named: 'password'),
        )).thenThrow(AppwriteException('Credenciales inválidas', 401));
    await pump(tester);

    await fill(tester, 'ana@b.cl', 'mala');
    await tester.tap(find.text('Iniciar sesión'));
    await tester.pumpAndSettle();

    expect(find.text('Credenciales inválidas'), findsOneWidget);
  });

  testWidgets('error inesperado muestra mensaje genérico', (tester) async {
    when(() => repo.login(
          email: any(named: 'email'),
          password: any(named: 'password'),
        )).thenThrow(Exception('boom'));
    await pump(tester);

    await fill(tester, 'ana@b.cl', 'clave');
    await tester.tap(find.text('Iniciar sesión'));
    await tester.pumpAndSettle();

    expect(find.text('Error inesperado. Revisa tu conexión.'), findsOneWidget);
  });

  testWidgets('el botón se deshabilita mientras carga', (tester) async {
    when(() => repo.login(
          email: any(named: 'email'),
          password: any(named: 'password'),
        )).thenAnswer((_) async {
      await Future<void>.delayed(const Duration(seconds: 1));
      return MockSession();
    });
    await pump(tester);

    await fill(tester, 'ana@b.cl', 'clave');
    await tester.tap(find.text('Iniciar sesión'));
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(
      tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
      isNull,
    );
    await tester.pumpAndSettle();
  });

  testWidgets('el enlace lleva a register', (tester) async {
    await pump(tester);
    await tester.tap(find.text('¿No tienes cuenta? Regístrate'));
    await tester.pumpAndSettle();

    expect(find.text('STUB /register'), findsOneWidget);
  });
}
