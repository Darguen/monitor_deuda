import 'dart:async';
import 'dart:io';

import 'package:appwrite/appwrite.dart';

/// Errores que vale la pena reintentar: sin respuesta (red), timeout,
/// 408, 429 y 5xx. Nunca 400/401/403/404/409.
bool isTransientError(Object e) {
  if (e is AppwriteException) {
    final code = e.code;
    return code == null ||
        code == 0 ||
        code == 408 ||
        code == 429 ||
        code >= 500;
  }
  return e is SocketException || e is TimeoutException;
}

/// Ejecuta [action] y la reintenta con backoff exponencial
/// (baseDelay, 2x, 4x...) mientras el error sea transitorio.
Future<T> withRetry<T>(
  Future<T> Function() action, {
  int maxAttempts = 3,
  Duration baseDelay = const Duration(milliseconds: 300),
}) async {
  var attempt = 0;
  while (true) {
    attempt++;
    try {
      return await action();
    } catch (e) {
      if (attempt >= maxAttempts || !isTransientError(e)) rethrow;
      await Future<void>.delayed(baseDelay * (1 << (attempt - 1)));
    }
  }
}

/// Creación idempotente: [create] debe usar un ID generado de antemano.
/// Si tras un reintento el servidor responde 409, el intento anterior sí
/// llegó a crearlo (solo se perdió la respuesta), así que se devuelve el
/// recurso existente con [fetch].
Future<T> retryCreate<T>({
  required Future<T> Function() create,
  required Future<T> Function() fetch,
  int maxAttempts = 3,
  Duration baseDelay = const Duration(milliseconds: 300),
}) async {
  var attempts = 0;
  try {
    return await withRetry(
      () {
        attempts++;
        return create();
      },
      maxAttempts: maxAttempts,
      baseDelay: baseDelay,
    );
  } on AppwriteException catch (e) {
    if (e.code == 409 && attempts > 1) {
      return withRetry(fetch, baseDelay: baseDelay);
    }
    rethrow;
  }
}

/// Borrado idempotente: con retry, y un 404 cuenta como éxito.
Future<void> retryDelete(
  Future<void> Function() delete, {
  Duration baseDelay = const Duration(milliseconds: 300),
}) async {
  try {
    await withRetry(delete, baseDelay: baseDelay);
  } on AppwriteException catch (e) {
    if (e.code != 404) rethrow;
  }
}

/// Para rollbacks: intenta [action] y traga cualquier error, de modo que
/// un fallo al deshacer no tape el error original.
Future<void> bestEffort(Future<void> Function() action) async {
  try {
    await action();
  } catch (_) {}
}
