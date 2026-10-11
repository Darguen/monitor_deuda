import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:monitor_deuda/features/auth/presentation/auth_controller.dart';
import 'package:monitor_deuda/features/groups/data/groups_repository.dart';
import 'package:monitor_deuda/features/groups/presentation/groups_controller.dart';

import '../../../helpers/app_harness.dart';
import '../../../helpers/fixtures.dart';

void main() {
  late MockGroupsRepository repo;

  setUp(() => repo = MockGroupsRepository());

  Future<ProviderContainer> make({required bool loggedIn}) async {
    final c = ProviderContainer(overrides: [
      ...fakeAuthOverride(loggedIn ? makeUser() : null),
      groupsRepositoryProvider.overrideWithValue(repo),
    ]);
    addTearDown(c.dispose);
    await c.read(authControllerProvider.future);
    return c;
  }

  group('build', () {
    test('sin sesión devuelve lista vacía sin llamar al repositorio', () async {
      final c = await make(loggedIn: false);
      expect(await c.read(groupsControllerProvider.future), isEmpty);
      verifyNever(() => repo.listGroups());
    });

    test('con sesión lista los grupos del repositorio', () async {
      when(() => repo.listGroups()).thenAnswer((_) async => [testGroup]);
      final c = await make(loggedIn: true);
      expect(await c.read(groupsControllerProvider.future), [testGroup]);
    });
  });

  group('createGroup', () {
    test('crea el grupo y recarga la lista', () async {
      when(() => repo.listGroups()).thenAnswer((_) async => []);
      when(() => repo.createGroup(name: any(named: 'name')))
          .thenAnswer((_) async => testGroup);
      final c = await make(loggedIn: true);
      await c.read(groupsControllerProvider.future);

      when(() => repo.listGroups()).thenAnswer((_) async => [testGroup]);
      await c.read(groupsControllerProvider.notifier).createGroup('Viaje');

      verify(() => repo.createGroup(name: 'Viaje')).called(1);
      expect(c.read(groupsControllerProvider).value, [testGroup]);
    });
  });

  group('refresh', () {
    test('vuelve a pedir los grupos', () async {
      when(() => repo.listGroups()).thenAnswer((_) async => []);
      final c = await make(loggedIn: true);
      await c.read(groupsControllerProvider.future);

      await c.read(groupsControllerProvider.notifier).refresh();

      verify(() => repo.listGroups()).called(2);
    });
  });
}
