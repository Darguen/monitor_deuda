import 'package:appwrite/appwrite.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:monitor_deuda/features/auth/presentation/auth_controller.dart';
import 'package:monitor_deuda/features/home/home_screen.dart';

import '../../helpers/app_harness.dart';
import '../../helpers/fixtures.dart';

void main() {
  late MockGroupsRepository groups;

  setUp(() {
    groups = MockGroupsRepository();
    when(() => groups.listGroups()).thenAnswer((_) async => []);
  });

  Future<void> pump(WidgetTester tester) => pumpScreen(
        tester,
        const HomeScreen(),
        overrides: [
          ...fakeAuthOverride(makeUser()),
          ...repoOverrides(groups: groups),
        ],
        stubs: ['/groups/g1'],
      );

  testWidgets('sin grupos muestra el mensaje vacío', (tester) async {
    await pump(tester);
    expect(find.textContaining('Aún no tienes grupos'), findsOneWidget);
  });

  testWidgets('lista los grupos con su moneda', (tester) async {
    when(() => groups.listGroups()).thenAnswer((_) async => [testGroup]);
    await pump(tester);

    expect(find.text('Viaje'), findsOneWidget);
    expect(find.text('CLP'), findsOneWidget);
  });

  testWidgets('tocar un grupo navega a su detalle', (tester) async {
    when(() => groups.listGroups()).thenAnswer((_) async => [testGroup]);
    await pump(tester);

    await tester.tap(find.text('Viaje'));
    await tester.pumpAndSettle();

    expect(find.text('STUB /groups/g1'), findsOneWidget);
  });

  testWidgets('error de carga muestra reintentar', (tester) async {
    var calls = 0;
    when(() => groups.listGroups()).thenAnswer((_) async {
      calls++;
      if (calls == 1) throw Exception('sin red');
      return [testGroup];
    });
    await pump(tester);

    expect(find.text('No se pudieron cargar los grupos'), findsOneWidget);

    await tester.tap(find.text('Reintentar'));
    await tester.pumpAndSettle();

    expect(find.text('Viaje'), findsOneWidget);
  });

  testWidgets('crear grupo: pide nombre y llama al repositorio',
      (tester) async {
    when(() => groups.createGroup(name: any(named: 'name')))
        .thenAnswer((_) async => testGroup);
    await pump(tester);

    await tester.tap(find.byIcon(Icons.add));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '  Viaje a Pucón ');
    await tester.tap(find.text('Crear'));
    await tester.pumpAndSettle();

    verify(() => groups.createGroup(name: 'Viaje a Pucón')).called(1);
  });

  testWidgets('crear grupo con nombre vacío no llama al repositorio',
      (tester) async {
    await pump(tester);

    await tester.tap(find.byIcon(Icons.add));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Crear'));
    await tester.pumpAndSettle();

    verifyNever(() => groups.createGroup(name: any(named: 'name')));
  });

  testWidgets('cancelar el diálogo no crea nada', (tester) async {
    await pump(tester);

    await tester.tap(find.byIcon(Icons.add));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Algo');
    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();

    verifyNever(() => groups.createGroup(name: any(named: 'name')));
  });

  testWidgets('si crear falla muestra el mensaje en un snackbar',
      (tester) async {
    when(() => groups.createGroup(name: any(named: 'name')))
        .thenThrow(AppwriteException('Sin permisos', 401));
    await pump(tester);

    await tester.tap(find.byIcon(Icons.add));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Viaje');
    await tester.tap(find.text('Crear'));
    await tester.pumpAndSettle();

    expect(find.text('Sin permisos'), findsOneWidget);
  });

  testWidgets('el botón de salir cierra la sesión', (tester) async {
    await pump(tester);

    final container =
        ProviderScope.containerOf(tester.element(find.byType(HomeScreen)));
    expect(container.read(authControllerProvider).value, isNotNull);

    await tester.tap(find.byIcon(Icons.logout));
    await tester.pumpAndSettle();

    expect(container.read(authControllerProvider).value, isNull);
  });

}
