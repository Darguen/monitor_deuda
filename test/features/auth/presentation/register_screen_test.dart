import 'package:appwrite/appwrite.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:monitor_deuda/features/auth/presentation/register_screen.dart';

import '../../../helpers/app_harness.dart';
import '../../../helpers/fixtures.dart';

void main() {
  late MockAuthRepository repo;

  setUp(() {
    repo = MockAuthRepository();
    when(() => repo.currentUser()).thenAnswer((_) async => null);
  });

  Future<void> pump(WidgetTester tester) => pumpScreen(
        tester,
        const RegisterScreen(),
        overrides: authOverrides(repo),
      );

  Future<void> fill(
      WidgetTester tester, String name, String email, String pass) async {
    await tester.enterText(find.widgetWithText(TextFormField, 'Nombre'), name);
    await tester.enterText(find.widgetWithText(TextFormField, 'Correo'), email);
    await tester.enterText(
        find.widgetWithText(TextFormField, 'Contraseña (mínimo 8 caracteres)'),
        pass);
  }

  void stubRegister() {
    when(() => repo.register(
          name: any(named: 'name'),
          email: any(named: 'email'),
          password: any(named: 'password'),
        )).thenAnswer((_) async => makeUser());
  }

  testWidgets('campos vacíos muestran errores', (tester) async {
    await pump(tester);
    await tester.tap(find.widgetWithText(FilledButton, 'Crear cuenta'));
    await tester.pump();

    expect(find.text('Ingresa tu nombre'), findsOneWidget);
    expect(find.text('Ingresa tu correo'), findsOneWidget);
    expect(find.text('Mínimo 8 caracteres'), findsOneWidget);
  });

  testWidgets('contraseña de 7 caracteres es rechazada', (tester) async {
    await pump(tester);
    await fill(tester, 'Ana', 'ana@b.cl', '1234567');
    await tester.tap(find.widgetWithText(FilledButton, 'Crear cuenta'));
    await tester.pump();

    expect(find.text('Mínimo 8 caracteres'), findsOneWidget);
    verifyNever(() => repo.register(
          name: any(named: 'name'),
          email: any(named: 'email'),
          password: any(named: 'password'),
        ));
  });

  testWidgets('con datos válidos registra con valores recortados',
      (tester) async {
    stubRegister();
    await pump(tester);

    await fill(tester, '  Ana ', ' ana@b.cl ', '12345678');
    await tester.tap(find.widgetWithText(FilledButton, 'Crear cuenta'));
    await tester.pumpAndSettle();

    verify(() => repo.register(
          name: 'Ana',
          email: 'ana@b.cl',
          password: '12345678',
        )).called(1);
  });

  testWidgets('muestra el mensaje de AppwriteException', (tester) async {
    when(() => repo.register(
          name: any(named: 'name'),
          email: any(named: 'email'),
          password: any(named: 'password'),
        )).thenThrow(AppwriteException('Correo ya registrado', 409));
    await pump(tester);

    await fill(tester, 'Ana', 'ana@b.cl', '12345678');
    await tester.tap(find.widgetWithText(FilledButton, 'Crear cuenta'));
    await tester.pumpAndSettle();

    expect(find.text('Correo ya registrado'), findsOneWidget);
  });

  testWidgets('error inesperado muestra mensaje genérico', (tester) async {
    when(() => repo.register(
          name: any(named: 'name'),
          email: any(named: 'email'),
          password: any(named: 'password'),
        )).thenThrow(Exception('boom'));
    await pump(tester);

    await fill(tester, 'Ana', 'ana@b.cl', '12345678');
    await tester.tap(find.widgetWithText(FilledButton, 'Crear cuenta'));
    await tester.pumpAndSettle();

    expect(find.text('Error inesperado. Revisa tu conexión.'), findsOneWidget);
  });

  testWidgets('el enlace lleva a login', (tester) async {
    await pump(tester);
    await tester.tap(find.text('¿Ya tienes cuenta? Inicia sesión'));
    await tester.pumpAndSettle();

    expect(find.text('STUB /login'), findsOneWidget);
  });
}
