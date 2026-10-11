import 'package:appwrite/appwrite.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:monitor_deuda/core/appwrite/appwrite_providers.dart';
import 'package:monitor_deuda/features/auth/data/auth_repository.dart';

import '../../../helpers/fixtures.dart';

class MockAccount extends Mock implements Account {}

void main() {
  late MockAccount account;
  late AuthRepository repo;

  setUp(() {
    account = MockAccount();
    repo = AuthRepository(account);
  });

  void stubLogin() {
    when(() => account.createEmailPasswordSession(
          email: any(named: 'email'),
          password: any(named: 'password'),
        )).thenAnswer((_) async => MockSession());
  }

  group('login', () {
    test('crea una sesión con correo y contraseña', () async {
      stubLogin();
      await repo.login(email: 'a@b.cl', password: '12345678');
      verify(() => account.createEmailPasswordSession(
            email: 'a@b.cl',
            password: '12345678',
          )).called(1);
    });

    test('propaga el error de Appwrite', () {
      when(() => account.createEmailPasswordSession(
            email: any(named: 'email'),
            password: any(named: 'password'),
          )).thenThrow(AppwriteException('Credenciales inválidas', 401));
      expect(
        () => repo.login(email: 'a@b.cl', password: 'mala'),
        throwsA(isA<AppwriteException>()),
      );
    });
  });

  group('register', () {
    test('crea la cuenta, inicia sesión y devuelve el usuario', () async {
      final user = makeUser();
      when(() => account.create(
            userId: any(named: 'userId'),
            email: any(named: 'email'),
            password: any(named: 'password'),
            name: any(named: 'name'),
          )).thenAnswer((_) async => user);
      stubLogin();
      when(() => account.get()).thenAnswer((_) async => user);

      final result = await repo.register(
        name: 'Ana',
        email: 'a@b.cl',
        password: '12345678',
      );

      expect(result, same(user));
      verifyInOrder([
        () => account.create(
              userId: any(named: 'userId'),
              email: 'a@b.cl',
              password: '12345678',
              name: 'Ana',
            ),
        () => account.createEmailPasswordSession(
              email: 'a@b.cl',
              password: '12345678',
            ),
        () => account.get(),
      ]);
    });

    test('si falla la creación no intenta iniciar sesión', () async {
      when(() => account.create(
            userId: any(named: 'userId'),
            email: any(named: 'email'),
            password: any(named: 'password'),
            name: any(named: 'name'),
          )).thenThrow(AppwriteException('Ya existe', 409));

      await expectLater(
        repo.register(name: 'Ana', email: 'a@b.cl', password: '12345678'),
        throwsA(isA<AppwriteException>()),
      );
      verifyNever(() => account.createEmailPasswordSession(
            email: any(named: 'email'),
            password: any(named: 'password'),
          ));
    });
  });

  group('currentUser', () {
    test('devuelve el usuario si hay sesión', () async {
      final user = makeUser();
      when(() => account.get()).thenAnswer((_) async => user);
      expect(await repo.currentUser(), same(user));
    });

    test('devuelve null si Appwrite responde con error', () async {
      when(() => account.get()).thenThrow(AppwriteException('Sin sesión', 401));
      expect(await repo.currentUser(), isNull);
    });
  });

  group('logout', () {
    test('elimina la sesión actual', () async {
      when(() => account.deleteSession(sessionId: any(named: 'sessionId')))
          .thenAnswer((_) async {});
      await repo.logout();
      verify(() => account.deleteSession(sessionId: 'current')).called(1);
    });
  });

  group('authRepositoryProvider', () {
    test('construye el repositorio con el Account del provider', () {
      final container = ProviderContainer(
        overrides: [accountProvider.overrideWithValue(account)],
      );
      addTearDown(container.dispose);
      expect(container.read(authRepositoryProvider), isA<AuthRepository>());
    });
  });
}
