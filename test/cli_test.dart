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
      const original = 'class Example {\n  int z=0;\n  int a=0;\n}\n';
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
      final written = await file.readAsString();
      expect(written, isNot(original));
      expect(written, contains('int a = 0;'));
      expect(written, contains('int z = 0;'));

      exitCode = 0;
      await runCli(['--check', file.path]);
      expect(exitCode, 0);
    });

    test('preserves each file newline style when processing concurrently',
        () async {
      final lfFile = File('${directory.path}/lf.dart');
      final crlfFile = File('${directory.path}/crlf.dart');
      await lfFile.writeAsString(
        'class Example {\n  int z=0;\n  int a=0;\n}\n',
      );
      await crlfFile.writeAsString(
        'class Example {\r\n  int z=0;\r\n  int a=0;\r\n}\r\n',
      );

      await runCli(['--write', lfFile.path, crlfFile.path]);

      final lf = await lfFile.readAsString();
      final crlf = await crlfFile.readAsString();
      expect(lf, isNot(contains('\r')));
      expect(crlf.replaceAll('\r\n', ''), isNot(contains('\n')));
      expect(crlf, contains('int a = 0;\r\n'));
    });

    test('does not write any files if a matched Dart file cannot be parsed',
        () async {
      final valid = File('${directory.path}/a.dart');
      final invalid = File('${directory.path}/z.dart');
      const original = 'class Example {\n  int z=0;\n  int a=0;\n}\n';
      await valid.writeAsString(original);
      await invalid.writeAsString('class Broken { int value = ; }');

      await runCli(['--write', valid.path, invalid.path]);

      expect(exitCode, 2);
      expect(await valid.readAsString(), original);
    });
  });
}
