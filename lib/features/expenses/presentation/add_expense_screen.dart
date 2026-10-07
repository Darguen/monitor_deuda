import 'package:appwrite/appwrite.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/utils/money.dart';
import '../../auth/presentation/auth_controller.dart';
import '../../groups/data/members_repository.dart';
import '../../groups/presentation/groups_controller.dart';
import '../data/expenses_repository.dart';
import '../domain/split_logic.dart';

class AddExpenseScreen extends ConsumerStatefulWidget {
  const AddExpenseScreen({super.key, required this.groupId});
  final String groupId;

  @override
  ConsumerState<AddExpenseScreen> createState() => _AddExpenseScreenState();
}

class _AddExpenseScreenState extends ConsumerState<AddExpenseScreen> {
  final _formKey = GlobalKey<FormState>();
  final _description = TextEditingController();
  final _amount = TextEditingController();
  final Map<String, TextEditingController> _valueControllers = {};
  final Set<String> _participants = {};
  String? _paidBy;
  String _splitType = 'equal'; // equal | exact | percent
  bool _initialized = false;
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _description.dispose();
    _amount.dispose();
    for (final c in _valueControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  TextEditingController _ctrl(String memberId) =>
      _valueControllers.putIfAbsent(memberId, () => TextEditingController());

  int _valueOf(String memberId) => int.tryParse(_ctrl(memberId).text) ?? 0;

  int get _totalAmount => int.tryParse(_amount.text) ?? 0;

  int get _assignedSum =>
      _participants.fold<int>(0, (sum, id) => sum + _valueOf(id));

  void _changeSplitType(String type) {
    setState(() {
      _splitType = type;
      for (final c in _valueControllers.values) {
        c.clear();
      }
      _error = null;
    });
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_paidBy == null || _participants.isEmpty) {
      setState(() => _error = 'Elige quién pagó y al menos un participante');
      return;
    }

    final amount = int.parse(_amount.text);
    final ids = _participants.toList();
    late final Map<String, int> shares;

    if (_splitType == 'equal') {
      shares = splitEqually(amount, ids);
    } else if (_splitType == 'exact') {
      if (_assignedSum != amount) {
        setState(() => _error =
        'Los montos suman ${formatMoney(_assignedSum)}, pero el gasto es ${formatMoney(amount)}');
        return;
      }
      shares = {for (final id in ids) id: _valueOf(id)};
    } else {
      if (_assignedSum != 100) {
        setState(() =>
        _error = 'Los porcentajes suman $_assignedSum%, deben sumar 100%');
        return;
      }
      shares = splitByPercent(amount, {for (final id in ids) id: _valueOf(id)});
    }

    // Quien queda en 0 no participa del gasto.
    shares.removeWhere((_, v) => v <= 0);
    if (shares.isEmpty) {
      setState(() => _error = 'Nadie tiene una parte asignada');
      return;
    }

    final group = ref
        .read(groupsControllerProvider)
        .value
        ?.where((g) => g.id == widget.groupId)
        .firstOrNull;
    final user = ref.read(authControllerProvider).value;
    if (group == null || user == null) return;

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      await ref.read(expensesRepositoryProvider).addExpense(
        group: group,
        createdBy: user.$id,
        description: _description.text.trim(),
        amount: amount,
        paidBy: _paidBy!,
        splitType: _splitType,
        shares: shares,
      );
      ref.invalidate(expensesProvider(widget.groupId));
      ref.invalidate(splitsProvider(widget.groupId));
      if (mounted) context.pop();
    } on AppwriteException catch (e) {
      setState(() => _error = e.message ?? 'No se pudo guardar el gasto');
    } catch (e) {
      setState(() => _error = 'Error inesperado: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Widget _summary() {
    if (_splitType == 'equal') return const SizedBox.shrink();

    final String text;
    final bool ok;
    if (_splitType == 'exact') {
      final diff = _totalAmount - _assignedSum;
      ok = diff == 0 && _totalAmount > 0;
      text = diff == 0
          ? 'Todo asignado'
          : diff > 0
          ? 'Faltan ${formatMoney(diff)} por asignar'
          : 'Te pasaste por ${formatMoney(-diff)}';
    } else {
      ok = _assignedSum == 100;
      text = 'Suma: $_assignedSum% (debe ser 100%)';
    }

    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Text(
        text,
        style: TextStyle(
          fontWeight: FontWeight.w600,
          color: ok
              ? Colors.green.shade700
              : Theme.of(context).colorScheme.error,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final members = ref.watch(membersProvider(widget.groupId));
    final myUserId = ref.watch(authControllerProvider).value?.$id;

    return Scaffold(
      appBar: AppBar(title: const Text('Nuevo gasto')),
      body: members.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
        data: (list) {
          if (!_initialized) {
            _participants.addAll(list.map((m) => m.id));
            _paidBy = list
                .where((m) => m.userId == myUserId)
                .map((m) => m.id)
                .firstOrNull;
            _initialized = true;
          }

          return Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                TextFormField(
                  controller: _description,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(
                    labelText: 'Descripción (ej. Cena)',
                  ),
                  validator: (v) => (v == null || v.trim().isEmpty)
                      ? 'Ingresa una descripción'
                      : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _amount,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: const InputDecoration(
                    labelText: 'Monto',
                    prefixText: '\$ ',
                  ),
                  onChanged: (_) => setState(() {}),
                  validator: (v) {
                    final n = int.tryParse(v ?? '');
                    if (n == null || n <= 0) return 'Ingresa un monto válido';
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  initialValue: _paidBy,
                  decoration: const InputDecoration(labelText: 'Pagó'),
                  items: [
                    for (final m in list)
                      DropdownMenuItem(value: m.id, child: Text(m.displayName)),
                  ],
                  onChanged: (v) => setState(() => _paidBy = v),
                ),
                const SizedBox(height: 24),
                const Text('Cómo se divide',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: SegmentedButton<String>(
                    segments: const [
                      ButtonSegment(value: 'equal', label: Text('Iguales')),
                      ButtonSegment(value: 'exact', label: Text('Montos')),
                      ButtonSegment(value: 'percent', label: Text('Porcentajes')),
                    ],
                    selected: {_splitType},
                    onSelectionChanged: (s) => _changeSplitType(s.first),
                  ),
                ),
                const SizedBox(height: 8),
                for (final m in list)
                  if (_splitType == 'equal')
                    CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(m.displayName),
                      value: _participants.contains(m.id),
                      onChanged: (checked) => setState(() {
                        checked == true
                            ? _participants.add(m.id)
                            : _participants.remove(m.id);
                      }),
                    )
                  else
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Checkbox(
                        value: _participants.contains(m.id),
                        onChanged: (checked) => setState(() {
                          checked == true
                              ? _participants.add(m.id)
                              : _participants.remove(m.id);
                        }),
                      ),
                      title: Text(m.displayName),
                      trailing: SizedBox(
                        width: 110,
                        child: TextField(
                          controller: _ctrl(m.id),
                          enabled: _participants.contains(m.id),
                          keyboardType: TextInputType.number,
                          textAlign: TextAlign.end,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly
                          ],
                          decoration: InputDecoration(
                            isDense: true,
                            prefixText: _splitType == 'exact' ? '\$ ' : null,
                            suffixText: _splitType == 'percent' ? '%' : null,
                          ),
                          onChanged: (_) => setState(() {}),
                        ),
                      ),
                    ),
                _summary(),
                if (_error != null) ...[
                  const SizedBox(height: 8),
                  Text(_error!,
                      style: TextStyle(
                          color: Theme.of(context).colorScheme.error)),
                ],
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: _loading ? null : _save,
                  child: _loading
                      ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2))
                      : const Text('Guardar gasto'),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}