enum _OperationKind { equal, insert, remove }

class _DiffLine {
  const _DiffLine(this.text, this.hasNewline);

  final bool hasNewline;
  final String text;
}

class _DiffOperation {
  const _DiffOperation(this.kind, this.line);

  final _DiffLine line;
  final _OperationKind kind;
}

/// Returns a unified diff between [original] and [updated].
///
/// The comparison is line-based. Common prefixes and suffixes are removed
/// before computing an LCS, and very large changed regions fall back to a
/// single replacement block to bound memory use.
String unifiedDiff(String path, String original, String updated) {
  final oldLines = _splitLines(original);
  final newLines = _splitLines(updated);
  final operations = _diffLines(oldLines, newLines);
  final changedIndexes = <int>[
    for (var i = 0; i < operations.length; i++)
      if (operations[i].kind != _OperationKind.equal) i,
  ];
  if (changedIndexes.isEmpty) return '';

  const context = 3;
  final hunks = <(int, int)>[];
  var start = (changedIndexes.first - context).clamp(0, operations.length);
  var end = (changedIndexes.first + context + 1).clamp(0, operations.length);
  for (final index in changedIndexes.skip(1)) {
    final nextStart = (index - context).clamp(0, operations.length);
    final nextEnd = (index + context + 1).clamp(0, operations.length);
    if (nextStart <= end) {
      if (nextEnd > end) end = nextEnd;
    } else {
      hunks.add((start, end));
      start = nextStart;
      end = nextEnd;
    }
  }
  hunks.add((start, end));

  final output = StringBuffer()
    ..writeln('--- $path')
    ..writeln('+++ $path');
  for (final (hunkStart, hunkEnd) in hunks) {
    var oldBefore = 0;
    var newBefore = 0;
    for (var i = 0; i < hunkStart; i++) {
      final kind = operations[i].kind;
      if (kind != _OperationKind.insert) oldBefore++;
      if (kind != _OperationKind.remove) newBefore++;
    }

    var oldCount = 0;
    var newCount = 0;
    for (var i = hunkStart; i < hunkEnd; i++) {
      final kind = operations[i].kind;
      if (kind != _OperationKind.insert) oldCount++;
      if (kind != _OperationKind.remove) newCount++;
    }
    final oldStart = oldCount == 0 ? oldBefore : oldBefore + 1;
    final newStart = newCount == 0 ? newBefore : newBefore + 1;
    output.writeln('@@ -$oldStart,$oldCount +$newStart,$newCount @@');

    for (var i = hunkStart; i < hunkEnd; i++) {
      final operation = operations[i];
      final prefix = switch (operation.kind) {
        _OperationKind.equal => ' ',
        _OperationKind.insert => '+',
        _OperationKind.remove => '-',
      };
      output.writeln('$prefix${operation.line.text}');
      if (!operation.line.hasNewline) {
        output.writeln(r'\ No newline at end of file');
      }
    }
  }
  return output.toString();
}

List<_DiffOperation> _diffLines(
  List<_DiffLine> oldLines,
  List<_DiffLine> newLines,
) {
  var prefixLength = 0;
  while (prefixLength < oldLines.length &&
      prefixLength < newLines.length &&
      _sameLine(oldLines[prefixLength], newLines[prefixLength])) {
    prefixLength++;
  }

  var suffixLength = 0;
  while (suffixLength < oldLines.length - prefixLength &&
      suffixLength < newLines.length - prefixLength &&
      _sameLine(
        oldLines[oldLines.length - suffixLength - 1],
        newLines[newLines.length - suffixLength - 1],
      )) {
    suffixLength++;
  }

  final operations = <_DiffOperation>[
    for (var i = 0; i < prefixLength; i++)
      _DiffOperation(_OperationKind.equal, oldLines[i]),
  ];
  final oldMiddle = oldLines.sublist(
    prefixLength,
    oldLines.length - suffixLength,
  );
  final newMiddle = newLines.sublist(
    prefixLength,
    newLines.length - suffixLength,
  );
  const maxLcsCells = 500000;
  const maxLcsLinesPerSide = 2000;

  if (oldMiddle.length > maxLcsLinesPerSide ||
      newMiddle.length > maxLcsLinesPerSide ||
      oldMiddle.length * newMiddle.length > maxLcsCells) {
    operations
      ..addAll(
        oldMiddle.map((line) => _DiffOperation(_OperationKind.remove, line)),
      )
      ..addAll(
        newMiddle.map((line) => _DiffOperation(_OperationKind.insert, line)),
      );
  } else {
    final lcs = List.generate(
      oldMiddle.length + 1,
      (_) => List<int>.filled(newMiddle.length + 1, 0),
    );
    for (var oldIndex = oldMiddle.length - 1; oldIndex >= 0; oldIndex--) {
      for (var newIndex = newMiddle.length - 1; newIndex >= 0; newIndex--) {
        lcs[oldIndex][newIndex] =
            _sameLine(oldMiddle[oldIndex], newMiddle[newIndex])
            ? lcs[oldIndex + 1][newIndex + 1] + 1
            : _max(lcs[oldIndex + 1][newIndex], lcs[oldIndex][newIndex + 1]);
      }
    }

    var oldIndex = 0;
    var newIndex = 0;
    while (oldIndex < oldMiddle.length || newIndex < newMiddle.length) {
      if (oldIndex < oldMiddle.length &&
          newIndex < newMiddle.length &&
          _sameLine(oldMiddle[oldIndex], newMiddle[newIndex])) {
        operations.add(
          _DiffOperation(_OperationKind.equal, oldMiddle[oldIndex]),
        );
        oldIndex++;
        newIndex++;
      } else if (newIndex < newMiddle.length &&
          (oldIndex == oldMiddle.length ||
              lcs[oldIndex][newIndex + 1] > lcs[oldIndex + 1][newIndex])) {
        operations.add(
          _DiffOperation(_OperationKind.insert, newMiddle[newIndex]),
        );
        newIndex++;
      } else {
        operations.add(
          _DiffOperation(_OperationKind.remove, oldMiddle[oldIndex]),
        );
        oldIndex++;
      }
    }
  }

  for (var i = oldLines.length - suffixLength; i < oldLines.length; i++) {
    operations.add(_DiffOperation(_OperationKind.equal, oldLines[i]));
  }
  return operations;
}

bool _sameLine(_DiffLine a, _DiffLine b) =>
    a.text == b.text && a.hasNewline == b.hasNewline;

int _max(int a, int b) => a > b ? a : b;

List<_DiffLine> _splitLines(String source) {
  if (source.isEmpty) return const [];
  final hasTrailingNewline = source.endsWith('\n');
  final lines = source.split('\n');
  if (hasTrailingNewline) lines.removeLast();
  return [
    for (var i = 0; i < lines.length; i++)
      _DiffLine(
        lines[i].endsWith('\r')
            ? lines[i].substring(0, lines[i].length - 1)
            : lines[i],
        i < lines.length - 1 || hasTrailingNewline,
      ),
  ];
}
