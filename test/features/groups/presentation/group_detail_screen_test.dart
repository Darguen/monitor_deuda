import 'package:appwrite/appwrite.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:monitor_deuda/features/expenses/domain/expense.dart';
import 'package:monitor_deuda/features/expenses/domain/settlement.dart';
import 'package:monitor_deuda/features/groups/presentation/group_detail_screen.dart';

import '../../../helpers/app_harness.dart';
import '../../../helpers/fixtures.dart';

final _expense = Expense(
  id: 'e1',
  groupId: 'g1',
  description: 'Cena',
  amount: 3000,
  paidBy: 'm1',
  createdAt: DateTime(2024),
);

const _splits = [
  ExpenseSplit(id: 's1', expenseId: 'e1', memberId: 'm1', share: 1500),
  ExpenseSplit(id: 's2', expenseId: 'e1', memberId: 'm2', share: 1500),
];

void main() {
  setUpAll(() => registerFallbackValue(testGroup));

  late MockGroupsRepository groups;
  late MockMembersRepository members;
  late MockExpensesRepository expenses;

  setUp(() {
    groups = MockGroupsRepository();
    members = MockMembersRepository();
    expenses = MockExpensesRepository();

    when(() => groups.listGroups()).thenAnswer((_) async => [testGroup]);
    when(() => members.listMembers(any())).thenAnswer((_) async => testMembers);
    when(() => expenses.listExpenses(any())).thenAnswer((_) async => []);
    when(() => expenses.listSplits(any())).thenAnswer((_) async => []);
    when(() => expenses.listSettlements(any())).thenAnswer((_) async => []);
  });

  Future<void> pump(WidgetTester tester) => pumpScreen(
        tester,
        const GroupDetailScreen(groupId: 'g1'),
        overrides: [
          ...fakeAuthOverride(makeUser()),
          ...repoOverrides(
              groups: groups, members: members, expenses: expenses),
        ],
      );

  void withExpense() {
    when(() => expenses.listExpenses(any()))
        .thenAnswer((_) async => [_expense]);
    when(() => expenses.listSplits(any())).thenAnswer((_) async => _splits);
  }

  testWidgets('muestra el nombre del grupo y los miembros', (tester) async {
    await pump(tester);

    expect(find.text('Viaje'), findsOneWidget);
    expect(find.text('Ana'), findsOneWidget);
    expect(find.text('Beto'), findsOneWidget);
    expect(find.text('Sin cuenta'), findsOneWidget);
  });

  testWidgets('sin gastos todos están al día y se invita a agregar',
      (tester) async {
    await pump(tester);

    expect(find.text('Al día'), findsNWidgets(2));
    expect(find.textContaining('Aún no hay gastos'), findsOneWidget);
    expect(find.text('Todo saldado'), findsNothing);
  });

  testWidgets('calcula saldos y pagos sugeridos', (tester) async {
    withExpense();
    await pump(tester);

    expect(find.text('Le deben \$1.500'), findsOneWidget);
    expect(find.text('Debe \$1.500'), findsOneWidget);
    expect(find.text('Beto → Ana'), findsOneWidget);
    expect(find.text('Pagó Ana'), findsOneWidget);
    expect(find.text('Cena'), findsOneWidget);
  });

  testWidgets('con gastos y saldos en cero muestra Todo saldado',
      (tester) async {
    withExpense();
    when(() => expenses.listSettlements(any())).thenAnswer((_) async => [
          Settlement(
            id: 'st1',
            groupId: 'g1',
            fromMember: 'm2',
            toMember: 'm1',
            amount: 1500,
            createdAt: DateTime(2024),
          ),
        ]);
    await pump(tester);

    expect(find.text('Todo saldado'), findsOneWidget);
    expect(find.text('Pagos registrados'), findsOneWidget);
    expect(find.text('Beto pagó a Ana'), findsOneWidget);
  });

  testWidgets('registrar pago confirma y guarda el settlement', (tester) async {
    withExpense();
    when(() => expenses.addSettlement(
          group: any(named: 'group'),
          createdBy: any(named: 'createdBy'),
          fromMember: any(named: 'fromMember'),
          toMember: any(named: 'toMember'),
          amount: any(named: 'amount'),
        )).thenAnswer((_) async {});
    await pump(tester);

    await tester.tap(find.text('Registrar pago'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Beto le pagó \$1.500 a Ana'), findsOneWidget);
    await tester.tap(find.text('Confirmar'));
    await tester.pumpAndSettle();

    verify(() => expenses.addSettlement(
          group: testGroup,
          createdBy: 'u1',
          fromMember: 'm2',
          toMember: 'm1',
          amount: 1500,
        )).called(1);
  });

  testWidgets('cancelar el registro de pago no guarda nada', (tester) async {
    withExpense();
    await pump(tester);

    await tester.tap(find.text('Registrar pago'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();

    verifyNever(() => expenses.addSettlement(
          group: any(named: 'group'),
          createdBy: any(named: 'createdBy'),
          fromMember: any(named: 'fromMember'),
          toMember: any(named: 'toMember'),
          amount: any(named: 'amount'),
        ));
  });

  testWidgets('mantener presionado un gasto lo borra con sus partes',
      (tester) async {
    withExpense();
    when(() => expenses.deleteExpense(
          expenseId: any(named: 'expenseId'),
          splitIds: any(named: 'splitIds'),
        )).thenAnswer((_) async {});
    await pump(tester);

    await tester.longPress(find.text('Cena'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Confirmar'));
    await tester.pumpAndSettle();

    verify(() => expenses.deleteExpense(
          expenseId: 'e1',
          splitIds: ['s1', 's2'],
        )).called(1);
  });

  testWidgets('si borrar falla se muestra el mensaje', (tester) async {
    withExpense();
    when(() => expenses.deleteExpense(
          expenseId: any(named: 'expenseId'),
          splitIds: any(named: 'splitIds'),
        )).thenThrow(AppwriteException('Sin permiso', 401));
    await pump(tester);

    await tester.longPress(find.text('Cena'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Confirmar'));
    await tester.pumpAndSettle();

    expect(find.text('Sin permiso'), findsOneWidget);
  });

  testWidgets('agregar miembro pide nombre y llama al repositorio',
      (tester) async {
    when(() => members.addMember(
          group: any(named: 'group'),
          displayName: any(named: 'displayName'),
        )).thenAnswer((_) async {});
    await pump(tester);

    await tester.tap(find.byIcon(Icons.person_add));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), ' Carla ');
    await tester.tap(find.text('Agregar'));
    await tester.pumpAndSettle();

    verify(() => members.addMember(group: testGroup, displayName: 'Carla'))
        .called(1);
  });

  testWidgets('agregar miembro con nombre vacío no hace nada', (tester) async {
    await pump(tester);

    await tester.tap(find.byIcon(Icons.person_add));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Agregar'));
    await tester.pumpAndSettle();

    verifyNever(() => members.addMember(
          group: any(named: 'group'),
          displayName: any(named: 'displayName'),
        ));
  });

  testWidgets('el botón Gasto navega a nuevo gasto', (tester) async {
    await pump(tester);

    await tester.tap(find.text('Gasto'));
    await tester.pumpAndSettle();

    expect(find.text('STUB new-expense g1'), findsOneWidget);
  });

  testWidgets('si el grupo no existe muestra un indicador de carga',
      (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ...fakeAuthOverride(makeUser()),
          ...repoOverrides(groups: groups, members: members, expenses: expenses),
        ],
        child: const MaterialApp(home: GroupDetailScreen(groupId: 'zzz')),
      ),
    );
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });
}
