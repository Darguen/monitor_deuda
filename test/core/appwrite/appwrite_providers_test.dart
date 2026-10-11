import 'dart:io';

import 'package:appwrite/appwrite.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monitor_deuda/core/appwrite/appwrite_providers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // El Client de Appwrite pide una carpeta donde guardar cookies.
  setUpAll(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (_) async => Directory.systemTemp.path,
    );
  });

  group('appwrite providers', () {
    late ProviderContainer container;

    setUp(() => container = ProviderContainer());
    tearDown(() => container.dispose());

    test('appwriteClientProvider entrega un Client', () {
      expect(container.read(appwriteClientProvider), isA<Client>());
    });

    test('el Client es el mismo en cada lectura', () {
      expect(
        container.read(appwriteClientProvider),
        same(container.read(appwriteClientProvider)),
      );
    });

    test('accountProvider entrega un Account', () {
      expect(container.read(accountProvider), isA<Account>());
    });

    test('databasesProvider entrega un Databases', () {
      expect(container.read(databasesProvider), isA<Databases>());
    });

    test('teamsProvider entrega un Teams', () {
      expect(container.read(teamsProvider), isA<Teams>());
    });
  });
}
