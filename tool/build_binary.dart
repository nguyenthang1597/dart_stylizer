import 'dart:io';

import 'package:path/path.dart' as p;

Future<void> main(List<String> arguments) async {
  if (arguments.length > 1) {
    stderr.writeln('Usage: dart run tool/build_binary.dart [output-path]');
    exitCode = 64;
    return;
  }

  final projectRoot = File.fromUri(Platform.script).parent.parent.path;
  final defaultName =
      Platform.isWindows ? 'dart_stylizer.exe' : 'dart_stylizer';
  final requestedOutput =
      arguments.isEmpty ? p.join('build', defaultName) : arguments.single;
  final outputPath = p.isAbsolute(requestedOutput)
      ? requestedOutput
      : p.join(projectRoot, requestedOutput);

  try {
    await Directory(p.dirname(outputPath)).create(recursive: true);
    final process = await Process.start(
      Platform.resolvedExecutable,
      [
        'compile',
        'exe',
        'bin/dart_stylizer.dart',
        '-o',
        outputPath,
      ],
      workingDirectory: projectRoot,
      mode: ProcessStartMode.inheritStdio,
    );
    exitCode = await process.exitCode;
  } on Object catch (error) {
    stderr.writeln('Failed to build dart_stylizer: $error');
    exitCode = 1;
  }
}
