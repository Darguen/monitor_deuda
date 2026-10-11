import 'package:appwrite/appwrite.dart';
import 'package:appwrite/models.dart' as models;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:monitor_deuda/features/auth/data/auth_repository.dart';
import 'package:monitor_deuda/features/auth/presentation/auth_controller.dart';

import '../../../helpers/fixtures.dart';

class MockAuthRepository extends Mock implements AuthRepository {}

void main() {
  late MockAuthRepository repo;
  late ProviderContainer container;

  ProviderContainer makeContainer() {
    final c = ProviderContainer(
      overrides: [authRepositoryProvider.overrideWithValue(repo)],
    );
    addTearDown(c.dispose);
    return c;
  }

  setUp(() => repo = MockAuthRepository());

  group('build', () {
    test('carga el usuario actual', () async {
      final user = makeUser();
      when(() => repo.currentUser()).thenAnswer((_) async => user);
      container = makeContainer();
      expect(await container.read(authControllerProvider.future), same(user));
    });

    test('sin sesión el estado es null', () async {
      when(() => repo.currentUser()).thenAnswer((_) async => null);
      container = makeContainer();
      expect(await container.read(authControllerProvider.future), isNull);
    });
  });

  group('login', () {
    test('inicia sesión y actualiza el usuario', () async {
      final user = makeUser();
      var logged = false;
      when(() => repo.currentUser())
          .thenAnswer((_) async => logged ? user : null);
      when(() => repo.login(
            email: any(named: 'email'),
            password: any(named: 'password'),
          )).thenAnswer((_) async {
        logged = true;
        return MockSession();
      });
      container = makeContainer();
      await container.read(authControllerProvider.future);

      await container
          .read(authControllerProvider.notifier)
          .login('a@b.cl', '12345678');

      verify(() => repo.login(email: 'a@b.cl', password: '12345678'))
          .called(1);
      expect(container.read(authControllerProvider).value, same(user));
    });

    test('propaga el error y mantiene el estado', () async {
      when(() => repo.currentUser()).thenAnswer((_) async => null);
      when(() => repo.login(
            email: any(named: 'email'),
            password: any(named: 'password'),
          )).thenThrow(AppwriteException('mala', 401));
      container = makeContainer();
      await container.read(authControllerProvider.future);

      await expectLater(
        container
            .read(authControllerProvider.notifier)
            .login('a@b.cl', 'mala'),
        throwsA(isA<AppwriteException>()),
      );
      expect(container.read(authControllerProvider).value, isNull);
    });
  });

  group('register', () {
    test('registra y deja al usuario en el estado', () async {
      final user = makeUser();
      when(() => repo.currentUser()).thenAnswer((_) async => null);
      when(() => repo.register(
            name: any(named: 'name'),
            email: any(named: 'email'),
            password: any(named: 'password'),
          )).thenAnswer((_) async => user);
      container = makeContainer();
      await container.read(authControllerProvider.future);

      await container
          .read(authControllerProvider.notifier)
          .register('Ana', 'a@b.cl', '12345678');

      verify(() => repo.register(
            name: 'Ana',
            email: 'a@b.cl',
            password: '12345678',
          )).called(1);
      expect(
        container.read(authControllerProvider).value,
        isA<models.User>().having((u) => u.$id, 'id', 'u1'),
      );
    });
  });

  group('logout', () {
    test('cierra sesión y deja el estado en null', () async {
      when(() => repo.currentUser()).thenAnswer((_) async => makeUser());
      when(() => repo.logout()).thenAnswer((_) async {});
      container = makeContainer();
      await container.read(authControllerProvider.future);

      await container.read(authControllerProvider.notifier).logout();

      verify(() => repo.logout()).called(1);
      expect(container.read(authControllerProvider).value, isNull);
    });
  });
}
