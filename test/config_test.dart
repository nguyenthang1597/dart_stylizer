import 'dart:io';

import 'package:dart_stylizer/dart_stylizer.dart';
import 'package:test/test.dart';

void main() {
  group('StylizerConfig', () {
    test('uses the documented defaults', () {
      final config = StylizerConfig.fromJson({});
      expect(config.memberOrdering, defaultMemberOrdering);
      expect(config.sortOtherMethods, isFalse);
    });

    test('rejects unknown member groups', () {
      expect(
        () => StylizerConfig.fromJson({
          'memberOrdering': ['made-up-group'],
        }),
        throwsFormatException,
      );
    });

    test('rejects duplicate member groups', () {
      expect(
        () => StylizerConfig.fromJson({
          'memberOrdering': ['build-method', 'build-method'],
        }),
        throwsFormatException,
      );
    });

    test('rejects unknown options and null boolean values', () {
      expect(
        () => StylizerConfig.fromJson({'unknownOption': true}),
        throwsFormatException,
      );
      expect(
        () => StylizerConfig.fromJson({'sortOtherMethods': null}),
        throwsFormatException,
      );
    });

    test('accepts a custom member ordering', () {
      final config = StylizerConfig.fromJson({
        'memberOrdering': ['build-method', 'public-constructor'],
      });
      expect(config.memberOrdering, ['build-method', 'public-constructor']);
    });

    test('rejects invalid JSON and missing explicit config files', () async {
      final directory = await Directory.systemTemp.createTemp(
        'dart_stylizer_config_test',
      );
      addTearDown(() => directory.delete(recursive: true));
      final file = File('${directory.path}/invalid.json');
      await file.writeAsString('{');

      expect(() => StylizerConfig.load(file.path), throwsFormatException);
      expect(
        () => StylizerConfig.load('${directory.path}/missing.json'),
        throwsA(isA<FileSystemException>()),
      );
    });
  });
}
