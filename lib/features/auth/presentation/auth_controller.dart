import 'package:appwrite/models.dart' as models;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/auth_repository.dart';

/// Estado = usuario actual (null si no hay sesión).
class AuthController extends AsyncNotifier<models.User?> {
  @override
  Future<models.User?> build() {
    return ref.read(authRepositoryProvider).currentUser();
  }

  Future<void> login(String email, String password) async {
    final repo = ref.read(authRepositoryProvider);
    await repo.login(email: email, password: password);
    state = AsyncData(await repo.currentUser());
  }

  Future<void> register(String name, String email, String password) async {
    final repo = ref.read(authRepositoryProvider);
    final user = await repo.register(
      name: name,
      email: email,
      password: password,
    );
    state = AsyncData(user);
  }

  Future<void> logout() async {
    await ref.read(authRepositoryProvider).logout();
    state = const AsyncData(null);
  }
}

final authControllerProvider =
AsyncNotifierProvider<AuthController, models.User?>(AuthController.new);