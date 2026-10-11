import 'dart:io';

import 'package:appwrite/appwrite.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monitor_deuda/core/utils/retry.dart';

void main() {
  const zero = Duration.zero;

  group('isTransientError', () {
    test('reintenta red, timeout, 408, 429 y 5xx', () {
      expect(isTransientError(AppwriteException('x')), isTrue);
      expect(isTransientError(AppwriteException('x', 408)), isTrue);
      expect(isTransientError(AppwriteException('x', 429)), isTrue);
      expect(isTransientError(AppwriteException('x', 503)), isTrue);
      expect(isTransientError(const SocketException('x')), isTrue);
    });

    test('no reintenta errores del cliente', () {
      for (final code in [400, 401, 403, 404, 409]) {
        expect(isTransientError(AppwriteException('x', code)), isFalse);
      }
      expect(isTransientError(StateError('x')), isFalse);
    });
  });

  group('withRetry', () {
    test('devuelve el resultado sin reintentar si funciona', () async {
      var calls = 0;
      final r = await withRetry(() async => ++calls, baseDelay: zero);
      expect(r, 1);
    });

    test('reintenta errores transitorios hasta tener éxito', () async {
      var calls = 0;
      final r = await withRetry(() async {
        if (++calls < 3) throw AppwriteException('boom', 500);
        return 'ok';
      }, baseDelay: zero);
      expect(r, 'ok');
      expect(calls, 3);
    });

    test('se rinde tras maxAttempts y lanza el último error', () async {
      var calls = 0;
      await expectLater(
        withRetry(() async {
          calls++;
          throw AppwriteException('boom', 503);
        }, baseDelay: zero),
        throwsA(isA<AppwriteException>()),
      );
      expect(calls, 3);
    });

    test('no reintenta errores no transitorios', () async {
      var calls = 0;
      await expectLater(
        withRetry(() async {
          calls++;
          throw AppwriteException('prohibido', 403);
        }, baseDelay: zero),
        throwsA(isA<AppwriteException>()),
      );
      expect(calls, 1);
    });
  });

  group('retryCreate', () {
    test('un 409 tras un reintento devuelve el recurso existente', () async {
      var calls = 0;
      final r = await retryCreate<String>(
        baseDelay: zero,
        create: () async {
          if (++calls == 1) throw AppwriteException('sin respuesta', 500);
          throw AppwriteException('ya existe', 409);
        },
        fetch: () async => 'existente',
      );
      expect(r, 'existente');
    });

    test('un 409 en el primer intento es un error real', () async {
      await expectLater(
        retryCreate<String>(
          baseDelay: zero,
          create: () async => throw AppwriteException('ya existe', 409),
          fetch: () async => 'existente',
        ),
        throwsA(isA<AppwriteException>()),
      );
    });
  });

  group('retryDelete', () {
    test('un 404 cuenta como borrado', () async {
      await retryDelete(
        () async => throw AppwriteException('no existe', 404),
        baseDelay: zero,
      );
    });

    test('otros errores se propagan', () async {
      await expectLater(
        retryDelete(
          () async => throw AppwriteException('prohibido', 403),
          baseDelay: zero,
        ),
        throwsA(isA<AppwriteException>()),
      );
    });
  });

  test('bestEffort traga errores', () async {
    await bestEffort(() async => throw StateError('x'));
  });
}
