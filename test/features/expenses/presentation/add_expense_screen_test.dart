import 'package:appwrite/appwrite.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:monitor_deuda/features/expenses/presentation/add_expense_screen.dart';
import 'package:monitor_deuda/features/groups/presentation/groups_controller.dart';

import '../../../helpers/app_harness.dart';
import '../../../helpers/fixtures.dart';

void main() {
  late MockGroupsRepository groups;
  late MockMembersRepository members;
  late MockExpensesRepository expenses;

  setUpAll(() => registerFallbackValue(testGroup));

  setUp(() {
    groups = MockGroupsRepository();
    members = MockMembersRepository();
    expenses = MockExpensesRepository();

    when(() => groups.listGroups()).thenAnswer((_) async => [testGroup]);
    when(() => members.listMembers(any())).thenAnswer((_) async => testMembers);
    when(() => expenses.listExpenses(any())).thenAnswer((_) async => []);
    when(() => expenses.listSplits(any())).thenAnswer((_) async => []);
  });

  void stubAdd() {
    when(() => expenses.addExpense(
          group: any(named: 'group'),
          createdBy: any(named: 'createdBy'),
          description: any(named: 'description'),
          amount: any(named: 'amount'),
          paidBy: any(named: 'paidBy'),
          shares: any(named: 'shares'),
          splitType: any(named: 'splitType'),
        )).thenAnswer((_) async {});
  }

  Future<void> pump(WidgetTester tester) async {
    await pumpScreen(
      tester,
      const AddExpenseScreen(groupId: 'g1'),
      overrides: [
        ...fakeAuthOverride(makeUser()),
        ...repoOverrides(groups: groups, members: members, expenses: expenses),
      ],
    );
    // El grupo debe estar cargado para poder guardar.
    final container = ProviderScope.containerOf(
        tester.element(find.byType(AddExpenseScreen)));
    await container.read(groupsControllerProvider.future);
  }

  Finder field(String label) => find.widgetWithText(TextFormField, label);

  Future<void> fillBasics(WidgetTester tester, {String amount = '3001'}) async {
    await tester.enterText(field('Descripción (ej. Cena)'), ' Cena ');
    await tester.enterText(field('Monto'), amount);
  }

  Finder memberField(String name) => find.descendant(
        of: find.widgetWithText(ListTile, name),
        matching: find.byType(TextField),
      );

  Future<void> save(WidgetTester tester) async {
    await tester.tap(find.text('Guardar gasto'));
    await tester.pumpAndSettle();
  }

  testWidgets('lista miembros y parte con todos marcados', (tester) async {
    await pump(tester);

    expect(find.text('Ana'), findsWidgets);
    expect(find.text('Beto'), findsWidgets);
    final checks = tester.widgetList<CheckboxListTile>(
      find.byType(CheckboxListTile),
    );
    expect(checks.every((c) => c.value == true), isTrue);
  });

  testWidgets('el pagador por defecto es el usuario actual', (tester) async {
    await pump(tester);

    final dropdown = tester.widget<DropdownButtonFormField<String>>(
      find.byType(DropdownButtonFormField<String>),
    );
    expect(dropdown.initialValue, 'm1');
  });

  testWidgets('descripción y monto son obligatorios', (tester) async {
    await pump(tester);
    await save(tester);

    expect(find.text('Ingresa una descripción'), findsOneWidget);
    expect(find.text('Ingresa un monto válido'), findsOneWidget);
    verifyNever(() => expenses.addExpense(
          group: any(named: 'group'),
          createdBy: any(named: 'createdBy'),
          description: any(named: 'description'),
          amount: any(named: 'amount'),
          paidBy: any(named: 'paidBy'),
          shares: any(named: 'shares'),
          splitType: any(named: 'splitType'),
        ));
  });

  testWidgets('monto 0 es inválido', (tester) async {
    await pump(tester);
    await fillBasics(tester, amount: '0');
    await save(tester);

    expect(find.text('Ingresa un monto válido'), findsOneWidget);
  });

  testWidgets('partes iguales: guarda sin perder pesos y vuelve atrás',
      (tester) async {
    stubAdd();
    await pump(tester);
    await fillBasics(tester);
    await save(tester);

    verify(() => expenses.addExpense(
          group: testGroup,
          createdBy: 'u1',
          description: 'Cena',
          amount: 3001,
          paidBy: 'm1',
          shares: {'m1': 1501, 'm2': 1500},
          splitType: 'equal',
        )).called(1);
    expect(find.text('ROOT'), findsOneWidget);
  });

  testWidgets('desmarcar un participante lo deja fuera del reparto',
      (tester) async {
    stubAdd();
    await pump(tester);
    await fillBasics(tester, amount: '1000');
    await tester.tap(find.widgetWithText(CheckboxListTile, 'Beto'));
    await tester.pump();
    await save(tester);

    verify(() => expenses.addExpense(
          group: any(named: 'group'),
          createdBy: any(named: 'createdBy'),
          description: any(named: 'description'),
          amount: 1000,
          paidBy: any(named: 'paidBy'),
          shares: {'m1': 1000},
          splitType: 'equal',
        )).called(1);
  });

  testWidgets('sin participantes muestra error', (tester) async {
    await pump(tester);
    await fillBasics(tester);
    await tester.tap(find.widgetWithText(CheckboxListTile, 'Ana'));
    await tester.tap(find.widgetWithText(CheckboxListTile, 'Beto'));
    await tester.pump();
    await save(tester);

    expect(find.text('Elige quién pagó y al menos un participante'),
        findsOneWidget);
  });

  testWidgets('montos exactos que no suman muestran error', (tester) async {
    await pump(tester);
    await fillBasics(tester, amount: '1000');
    await tester.tap(find.text('Montos'));
    await tester.pumpAndSettle();
    await tester.enterText(memberField('Ana'), '400');
    await tester.enterText(memberField('Beto'), '500');
    await tester.pump();

    expect(find.text('Faltan \$100 por asignar'), findsOneWidget);
    await save(tester);

    expect(
      find.text('Los montos suman \$900, pero el gasto es \$1.000'),
      findsOneWidget,
    );
  });

  testWidgets('montos exactos que suman se guardan', (tester) async {
    stubAdd();
    await pump(tester);
    await fillBasics(tester, amount: '1000');
    await tester.tap(find.text('Montos'));
    await tester.pumpAndSettle();
    await tester.enterText(memberField('Ana'), '400');
    await tester.enterText(memberField('Beto'), '600');
    await tester.pump();

    expect(find.text('Todo asignado'), findsOneWidget);
    await save(tester);

    verify(() => expenses.addExpense(
          group: any(named: 'group'),
          createdBy: any(named: 'createdBy'),
          description: any(named: 'description'),
          amount: 1000,
          paidBy: any(named: 'paidBy'),
          shares: {'m1': 400, 'm2': 600},
          splitType: 'exact',
        )).called(1);
  });

  testWidgets('pasarse del monto lo indica en el resumen', (tester) async {
    await pump(tester);
    await fillBasics(tester, amount: '1000');
    await tester.tap(find.text('Montos'));
    await tester.pumpAndSettle();
    await tester.enterText(memberField('Ana'), '1200');
    await tester.pump();

    expect(find.text('Te pasaste por \$200'), findsOneWidget);
  });

  testWidgets('porcentajes que no suman 100 muestran error', (tester) async {
    await pump(tester);
    await fillBasics(tester, amount: '1000');
    await tester.tap(find.text('Porcentajes'));
    await tester.pumpAndSettle();
    await tester.enterText(memberField('Ana'), '30');
    await tester.enterText(memberField('Beto'), '30');
    await tester.pump();
    await save(tester);

    expect(find.text('Los porcentajes suman 60%, deben sumar 100%'),
        findsOneWidget);
  });

  testWidgets('porcentajes 50/50 con monto impar se guardan exactos',
      (tester) async {
    stubAdd();
    await pump(tester);
    await fillBasics(tester, amount: '101');
    await tester.tap(find.text('Porcentajes'));
    await tester.pumpAndSettle();
    await tester.enterText(memberField('Ana'), '50');
    await tester.enterText(memberField('Beto'), '50');
    await tester.pump();
    await save(tester);

    final shares = verify(() => expenses.addExpense(
          group: any(named: 'group'),
          createdBy: any(named: 'createdBy'),
          description: any(named: 'description'),
          amount: 101,
          paidBy: any(named: 'paidBy'),
          shares: captureAny(named: 'shares'),
          splitType: 'percent',
        )).captured.single as Map<String, int>;
    expect(shares.values.fold<int>(0, (a, b) => a + b), 101);
  });

  testWidgets('cambiar el tipo de reparto limpia los valores', (tester) async {
    await pump(tester);
    await tester.tap(find.text('Montos'));
    await tester.pumpAndSettle();
    await tester.enterText(memberField('Ana'), '400');
    await tester.tap(find.text('Porcentajes'));
    await tester.pumpAndSettle();

    final field = tester.widget<TextField>(memberField('Ana'));
    expect(field.controller!.text, isEmpty);
  });

  testWidgets('muestra el mensaje de AppwriteException al fallar',
      (tester) async {
    when(() => expenses.addExpense(
          group: any(named: 'group'),
          createdBy: any(named: 'createdBy'),
          description: any(named: 'description'),
          amount: any(named: 'amount'),
          paidBy: any(named: 'paidBy'),
          shares: any(named: 'shares'),
          splitType: any(named: 'splitType'),
        )).thenThrow(AppwriteException('Sin permisos', 401));
    await pump(tester);
    await fillBasics(tester);
    await save(tester);

    expect(find.text('Sin permisos'), findsOneWidget);
    expect(find.text('ROOT'), findsNothing);
  });

  testWidgets('error inesperado muestra mensaje genérico', (tester) async {
    when(() => expenses.addExpense(
          group: any(named: 'group'),
          createdBy: any(named: 'createdBy'),
          description: any(named: 'description'),
          amount: any(named: 'amount'),
          paidBy: any(named: 'paidBy'),
          shares: any(named: 'shares'),
          splitType: any(named: 'splitType'),
        )).thenThrow(Exception('boom'));
    await pump(tester);
    await fillBasics(tester);
    await save(tester);

    expect(find.textContaining('Error inesperado'), findsOneWidget);
  });
}
