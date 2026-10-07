import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../auth/presentation/auth_controller.dart';
import '../data/groups_repository.dart';
import '../domain/group.dart';

class GroupsController extends AsyncNotifier<List<Group>> {
  @override
  Future<List<Group>> build() async {
    // Al depender del usuario, la lista se recarga si cambia la sesión.
    final user = ref.watch(authControllerProvider).value;
    if (user == null) return [];
    return ref.read(groupsRepositoryProvider).listGroups();
  }

  Future<void> createGroup(String name) async {
    await ref.read(groupsRepositoryProvider).createGroup(name: name);
    await refresh();
  }

  Future<void> refresh() async {
    ref.invalidateSelf();
    await future;
  }
}

final groupsControllerProvider =
AsyncNotifierProvider<GroupsController, List<Group>>(GroupsController.new);