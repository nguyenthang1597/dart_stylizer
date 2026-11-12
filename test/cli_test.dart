import 'dart:io';

import 'package:dart_stylizer/dart_stylizer.dart';
import 'package:test/test.dart';

void main() {
  group('runCli', () {
    late Directory directory;

    setUp(() async {
      directory = await Directory.systemTemp.createTemp('dart_stylizer_cli');
      exitCode = 0;
    });

    tearDown(() async {
      exitCode = 0;
      await directory.delete(recursive: true);
    });

    test('preview and check do not write while write mode does', () async {
      final file = File('${directory.path}/example.dart');
      const original = 'class Example {\n  int z = 0;\n  int a = 0;\n}\n';
      await file.writeAsString(original);

      await runCli(['--check', file.path]);
      expect(exitCode, 1);
      expect(await file.readAsString(), original);

      exitCode = 0;
      await runCli([file.path]);
      expect(await file.readAsString(), original);

      exitCode = 0;
      await runCli(['--write', file.path]);
      expect(exitCode, 0);
      expect(await file.readAsString(), isNot(original));
    });

    test('does not write any files if a matched Dart file cannot be parsed',
        () async {
      final valid = File('${directory.path}/a.dart');
      final invalid = File('${directory.path}/z.dart');
      const original = 'class Example {\n  int z = 0;\n  int a = 0;\n}\n';
      await valid.writeAsString(original);
      await invalid.writeAsString('class Broken { int value = ; }');

      await runCli(['--write', valid.path, invalid.path]);

      expect(exitCode, 2);
      expect(await valid.readAsString(), original);
    });
  });
}
