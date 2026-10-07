import 'package:appwrite/appwrite.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'appwrite_constants.dart';

final appwriteClientProvider = Provider<Client>((ref) {
  return Client()
    ..setEndpoint(AppwriteConstants.endpoint)
    ..setProject(AppwriteConstants.projectId);
});

final accountProvider = Provider<Account>(
      (ref) => Account(ref.watch(appwriteClientProvider)),
);

final databasesProvider = Provider<Databases>(
      (ref) => Databases(ref.watch(appwriteClientProvider)),
);

final teamsProvider = Provider<Teams>(
      (ref) => Teams(ref.watch(appwriteClientProvider)),
);