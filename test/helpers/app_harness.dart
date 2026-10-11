import 'package:appwrite/models.dart' as models;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:monitor_deuda/features/auth/data/auth_repository.dart';
import 'package:monitor_deuda/features/auth/presentation/auth_controller.dart';
import 'package:monitor_deuda/features/expenses/data/expenses_repository.dart';
import 'package:monitor_deuda/features/groups/data/groups_repository.dart';
import 'package:monitor_deuda/features/groups/data/members_repository.dart';

class MockAuthRepository extends Mock implements AuthRepository {}

class MockGroupsRepository extends Mock implements GroupsRepository {}

class MockMembersRepository extends Mock implements MembersRepository {}

class MockExpensesRepository extends Mock implements ExpensesRepository {}

/// AuthController con estado controlable desde el test.
class FakeAuthController extends AuthController {
  FakeAuthController(this._initial);
  final Future<models.User?> _initial;

  @override
  Future<models.User?> build() => _initial;

  void emit(models.User? user) => state = AsyncData(user);

  @override
  Future<void> logout() async => state = const AsyncData(null);
}

/// Monta [screen] en la ruta `/screen`, encima de una ruta raíz `/`,
/// así `context.pop()` y `context.go()` tienen a dónde ir.
/// Las rutas de [stubs] muestran solo su path como texto.
Future<GoRouter> pumpScreen(
  WidgetTester tester,
  Widget screen, {
  List<Override> overrides = const [],
  List<String> stubs = const ['/login', '/register', '/home'],
}) async {
  tester.view.physicalSize = const Size(800, 1600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  final router = GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(path: '/', builder: (_, _) => const Text('ROOT')),
      GoRoute(path: '/screen', builder: (_, _) => screen),
      for (final path in stubs)
        GoRoute(path: path, builder: (_, _) => Text('STUB $path')),
      GoRoute(
        path: '/groups/:id/expenses/new',
        builder: (_, s) => Text('STUB new-expense ${s.pathParameters['id']}'),
      ),
    ],
  );
  addTearDown(router.dispose);

  await tester.pumpWidget(
    ProviderScope(
      overrides: overrides,
      retry: (_, _) => null,
      child: MaterialApp.router(routerConfig: router),
    ),
  );
  router.push('/screen');
  await tester.pumpAndSettle();
  return router;
}

List<Override> authOverrides(AuthRepository repo) =>
    [authRepositoryProvider.overrideWithValue(repo)];

List<Override> fakeAuthOverride(models.User? user) => [
      authControllerProvider.overrideWith(
        () => FakeAuthController(Future.value(user)),
      ),
    ];

List<Override> repoOverrides({
  GroupsRepository? groups,
  MembersRepository? members,
  ExpensesRepository? expenses,
}) =>
    [
      if (groups != null) groupsRepositoryProvider.overrideWithValue(groups),
      if (members != null) membersRepositoryProvider.overrideWithValue(members),
      if (expenses != null)
        expensesRepositoryProvider.overrideWithValue(expenses),
    ];
