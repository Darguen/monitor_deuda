import 'package:flutter_test/flutter_test.dart';
import 'package:monitor_deuda/core/appwrite/appwrite_constants.dart';

void main() {
  group('AppwriteConstants', () {
    test('endpoint es https', () {
      expect(Uri.parse(AppwriteConstants.endpoint).scheme, 'https');
    });

    test('ids no están vacíos', () {
      for (final v in [
        AppwriteConstants.projectId,
        AppwriteConstants.databaseId,
        AppwriteConstants.groupsCollection,
        AppwriteConstants.membersCollection,
        AppwriteConstants.expensesCollection,
        AppwriteConstants.splitsCollection,
        AppwriteConstants.settlementsCollection,
      ]) {
        expect(v, isNotEmpty);
      }
    });

    test('las colecciones son distintas entre sí', () {
      final ids = {
        AppwriteConstants.groupsCollection,
        AppwriteConstants.membersCollection,
        AppwriteConstants.expensesCollection,
        AppwriteConstants.splitsCollection,
        AppwriteConstants.settlementsCollection,
      };
      expect(ids.length, 5);
    });
  });
}
