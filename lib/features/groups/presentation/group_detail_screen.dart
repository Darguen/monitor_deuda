import 'package:appwrite/appwrite.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/utils/money.dart';
import '../../auth/presentation/auth_controller.dart';
import '../../expenses/data/expenses_repository.dart';
import '../../expenses/domain/balances.dart';
import '../../expenses/domain/expense.dart';
import '../../expenses/domain/settlement.dart';
import '../../expenses/domain/simplify_debts.dart';
import '../data/members_repository.dart';
import '../domain/group.dart';
import 'groups_controller.dart';

class GroupDetailScreen extends ConsumerWidget {
  const GroupDetailScreen({super.key, required this.groupId});
  final String groupId;

  void _snack(BuildContext context, String text) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
    }
  }

  Future<bool> _confirm(
      BuildContext context, String title, String message) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Confirmar'),
          ),
        ],
      ),
    );
    return ok == true;
  }

  Future<void> _addMember(
      BuildContext context, WidgetRef ref, Group group) async {
    final controller = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Agregar miembro'),
        content: TextField(
          controller: controller,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(labelText: 'Nombre'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: const Text('Agregar'),
          ),
        ],
      ),
    );

    if (name == null || name.isEmpty) return;
    try {
      await ref
          .read(membersRepositoryProvider)
          .addMember(group: group, displayName: name);
      ref.invalidate(membersProvider(groupId));
    } on AppwriteException catch (e) {
      if (context.mounted) _snack(context, e.message ?? 'No se pudo agregar');
    }
  }

  Future<void> _registerPayment(BuildContext context, WidgetRef ref,
      Group group, Transfer t, Map<String, String> names) async {
    final ok = await _confirm(
      context,
      'Registrar pago',
      '¿${names[t.from] ?? '?'} le pagó ${formatMoney(t.amount)} '
          'a ${names[t.to] ?? '?'}?',
    );
    if (!ok) return;

    final user = ref.read(authControllerProvider).value;
    if (user == null) return;
    try {
      await ref.read(expensesRepositoryProvider).addSettlement(
        group: group,
        createdBy: user.$id,
        fromMember: t.from,
        toMember: t.to,
        amount: t.amount,
      );
      ref.invalidate(settlementsProvider(groupId));
    } on AppwriteException catch (e) {
      if (context.mounted) _snack(context, e.message ?? 'No se pudo registrar');
    }
  }

  Future<void> _deleteExpense(BuildContext context, WidgetRef ref, Expense e,
      List<ExpenseSplit> splits) async {
    final ok = await _confirm(
      context,
      'Borrar gasto',
      '¿Borrar "${e.description}" (${formatMoney(e.amount)})?',
    );
    if (!ok) return;

    try {
      await ref.read(expensesRepositoryProvider).deleteExpense(
        expenseId: e.id,
        splitIds:
        splits.where((s) => s.expenseId == e.id).map((s) => s.id).toList(),
      );
      ref.invalidate(expensesProvider(groupId));
      ref.invalidate(splitsProvider(groupId));
    } on AppwriteException catch (err) {
      if (context.mounted) _snack(context, err.message ?? 'No se pudo borrar');
    }
  }

  Widget _title(String text, {String? hint}) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        Text(text, style: const TextStyle(fontWeight: FontWeight.bold)),
        if (hint != null) ...[
          const SizedBox(width: 8),
          Text(hint, style: const TextStyle(fontSize: 12)),
        ],
      ],
    ),
  );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final group = ref
        .watch(groupsControllerProvider)
        .value
        ?.where((g) => g.id == groupId)
        .firstOrNull;

    if (group == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final members = ref.watch(membersProvider(groupId));
    final expenses = ref.watch(expensesProvider(groupId));
    final splits = ref.watch(splitsProvider(groupId));
    final settlements = ref.watch(settlementsProvider(groupId));
    final errorColor = Theme.of(context).colorScheme.error;

    final finance = [expenses, splits, settlements];
    final financeError =
        finance.where((a) => a.hasError).map((a) => a.error).firstOrNull;
    final financeReady = finance.every((a) => a.hasValue);

    return Scaffold(
      appBar: AppBar(
        title: Text(group.name),
        actions: [
          IconButton(
            icon: const Icon(Icons.person_add),
            tooltip: 'Agregar miembro',
            onPressed: () => _addMember(context, ref, group),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/groups/$groupId/expenses/new'),
        icon: const Icon(Icons.add),
        label: const Text('Gasto'),
      ),
      body: members.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text('$e', textAlign: TextAlign.center),
          ),
        ),
        data: (memberList) {
          final names = {for (final m in memberList) m.id: m.displayName};
          final expenseList = expenses.value ?? const <Expense>[];
          final splitList = splits.value ?? const <ExpenseSplit>[];
          final settlementList = settlements.value ?? const <Settlement>[];

          final balances = financeReady
              ? computeBalances(
            memberIds: memberList.map((m) => m.id).toList(),
            expenses: expenseList,
            splits: splitList,
            settlements: settlementList,
          )
              : <String, int>{};
          final transfers =
          financeReady ? simplifyDebts(balances) : <Transfer>[];

          return ListView(
            padding: const EdgeInsets.only(bottom: 88),
            children: [
              if (financeError != null)
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text('$financeError',
                      style: TextStyle(color: errorColor)),
                ),
              _title('Saldos'),
              for (final m in memberList)
                ListTile(
                  leading: CircleAvatar(
                    child: Text(m.displayName[0].toUpperCase()),
                  ),
                  title: Text(m.displayName),
                  subtitle: m.hasAccount ? null : const Text('Sin cuenta'),
                  trailing: Builder(builder: (_) {
                    if (!financeReady) return const SizedBox.shrink();
                    final b = balances[m.id] ?? 0;
                    if (b == 0) return const Text('Al día');
                    return Text(
                      b > 0
                          ? 'Le deben ${formatMoney(b)}'
                          : 'Debe ${formatMoney(-b)}',
                      style: TextStyle(
                        color: b > 0 ? Colors.green.shade700 : errorColor,
                        fontWeight: FontWeight.w600,
                      ),
                    );
                  }),
                ),
              if (financeReady && transfers.isNotEmpty) ...[
                _title('Pagos sugeridos'),
                for (final t in transfers)
                  ListTile(
                    leading: const CircleAvatar(child: Icon(Icons.swap_horiz)),
                    title: Text('${names[t.from] ?? '?'} → ${names[t.to] ?? '?'}'),
                    subtitle: Text(formatMoney(t.amount)),
                    trailing: TextButton(
                      onPressed: () =>
                          _registerPayment(context, ref, group, t, names),
                      child: const Text('Registrar pago'),
                    ),
                  ),
              ],
              if (financeReady && transfers.isEmpty && expenseList.isNotEmpty)
                const ListTile(
                  leading: CircleAvatar(child: Icon(Icons.check)),
                  title: Text('Todo saldado'),
                ),
              _title('Gastos', hint: 'mantén presionado para borrar'),
              if (expenseList.isEmpty && !expenses.hasError)
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text('Aún no hay gastos. Agrega el primero con +'),
                ),
              for (final e in expenseList)
                ListTile(
                  leading: const CircleAvatar(child: Icon(Icons.receipt_long)),
                  title: Text(e.description),
                  subtitle: Text('Pagó ${names[e.paidBy] ?? '?'}'),
                  trailing: Text(
                    formatMoney(e.amount),
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  onLongPress: () =>
                      _deleteExpense(context, ref, e, splitList),
                ),
              if (settlementList.isNotEmpty) ...[
                _title('Pagos registrados'),
                for (final s in settlementList)
                  ListTile(
                    leading: const CircleAvatar(child: Icon(Icons.payments)),
                    title: Text(
                        '${names[s.fromMember] ?? '?'} pagó a ${names[s.toMember] ?? '?'}'),
                    trailing: Text(
                      formatMoney(s.amount),
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
              ],
            ],
          );
        },
      ),
    );
  }
}