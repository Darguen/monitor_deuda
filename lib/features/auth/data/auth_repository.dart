import 'package:appwrite/appwrite.dart';
import 'package:appwrite/models.dart' as models;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/appwrite/appwrite_providers.dart';

class AuthRepository {
  AuthRepository(this._account);
  final Account _account;

  Future<models.User> register({
    required String name,
    required String email,
    required String password,
  }) async {
    await _account.create(
      userId: ID.unique(),
      email: email,
      password: password,
      name: name,
    );
    await login(email: email, password: password);
    return _account.get();
  }

  Future<models.Session> login({
    required String email,
    required String password,
  }) {
    return _account.createEmailPasswordSession(
      email: email,
      password: password,
    );
  }

  /// Devuelve null si no hay sesión activa.
  Future<models.User?> currentUser() async {
    try {
      return await _account.get();
    } on AppwriteException {
      return null;
    }
  }

  Future<void> logout() => _account.deleteSession(sessionId: 'current');
}

final authRepositoryProvider = Provider<AuthRepository>(
      (ref) => AuthRepository(ref.watch(accountProvider)),
);