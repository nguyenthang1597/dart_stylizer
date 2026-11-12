import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/analysis/utilities.dart';

import 'config.dart';

class DartOrganizer {
  const DartOrganizer(this.config);

  final StylizerConfig config;

  String organize(String source) {
    final parsed = parseString(content: source, throwIfDiagnostics: false);
    if (parsed.errors.isNotEmpty) return source;
    return organizeParsed(source, parsed.unit);
  }

  /// Organizes [source] using an already parsed compilation unit.
  ///
  /// The caller must ensure [unit] was parsed from [source] without errors.
  String organizeParsed(String source, CompilationUnit unit) {
    if (config.sortClassesWithinFile) {
      return _organizeDeclarations(source, unit);
    }
    return _organizeNodes(source, unit);
  }

  String _organizeNodes(String source, CompilationUnit unit) =>
      _rewrite(source, unit.declarations.where(_isOrganizable));

  String _organizeDeclarations(String source, CompilationUnit unit) {
    final rewritten = _rewrite(source, unit.declarations.where(_isOrganizable));
    final List<CompilationUnitMember> declarations;
    if (rewritten == source) {
      declarations = unit.declarations;
    } else {
      final reparsed = parseString(
        content: rewritten,
        throwIfDiagnostics: false,
      );
      if (reparsed.errors.isNotEmpty) return source;
      declarations = reparsed.unit.declarations;
    }
    final slots = <(int, int, String, String, int)>[];
    for (var i = 0; i < declarations.length; i++) {
      final declaration = declarations[i];
      if (!_isOrganizable(declaration)) continue;
      final lowerBound = i == 0 ? 0 : declarations[i - 1].end;
      final start = _leadingCommentStart(
        rewritten,
        declaration.offset,
        lowerBound,
      );
      slots.add((
        start,
        declaration.end,
        rewritten.substring(start, declaration.end),
        _declarationName(declaration),
        i,
      ));
    }
    if (slots.length < 2) return rewritten;

    final sorted = [...slots]
      ..sort((a, b) {
        final byName = a.$4.toLowerCase().compareTo(b.$4.toLowerCase());
        return byName == 0 ? a.$5.compareTo(b.$5) : byName;
      });
    final edits = <_Edit>[];
    for (var i = 0; i < slots.length; i++) {
      final slot = slots[i];
      final replacement = sorted[i].$3.trimRight();
      if (replacement != rewritten.substring(slot.$1, slot.$2)) {
        edits.add(_Edit(slot.$1, slot.$2, replacement));
      }
    }
    return _applyEdits(rewritten, edits);
  }

  bool _isOrganizable(AstNode node) =>
      node is ClassDeclaration ||
      (config.processEnumsLikeClasses && node is EnumDeclaration) ||
      (config.processEnumsLikeClasses && node is MixinDeclaration);
  String _rewrite(String source, Iterable<AstNode> declarations) {
    final edits = <_Edit>[];
    for (final declaration in declarations) {
      final members = switch (declaration) {
        final ClassDeclaration value => value.body.members,
        final EnumDeclaration value when config.processEnumsLikeClasses =>
          value.body.members,
        final MixinDeclaration value when config.processEnumsLikeClasses =>
          value.body.members,
        _ => const <ClassMember>[],
      };
      final sortableMembers = declaration is EnumDeclaration
          ? members
                .where((member) => member is! EnumConstantDeclaration)
                .toList()
          : members;
      if (sortableMembers.length < 2) continue;
      final declarationBody = switch (declaration) {
        final ClassDeclaration value => value.body,
        final EnumDeclaration value => value.body,
        final MixinDeclaration value => value.body,
        _ => null,
      };
      final open = switch (declarationBody) {
        final BlockClassBody value => value.leftBracket,
        final BlockEnumBody value => value.leftBracket,
        _ => null,
      };
      final close = switch (declarationBody) {
        final BlockClassBody value => value.rightBracket,
        final BlockEnumBody value => value.rightBracket,
        _ => null,
      };
      if (open == null || close == null) continue;
      final bodyStart = declaration is EnumDeclaration
          ? _leadingCommentStart(source, sortableMembers.first.offset, open.end)
          : open.end;
      final bodyEnd = close.offset;
      final chunks = <_MemberChunk>[];
      for (var i = 0; i < sortableMembers.length; i++) {
        final member = sortableMembers[i];
        final start = _leadingCommentStart(source, member.offset, bodyStart);
        final end = member.end;
        final info = _memberInfo(member);
        chunks.add(
          _MemberChunk(
            source.substring(start, end),
            info.category,
            info.name,
            i,
            member,
            typeName: info.typeName,
            isGetter: info.isGetter,
          ),
        );
      }
      if (chunks.any((chunk) => chunk.category == 'unclassified')) continue;
      final ordered = _order(chunks);
      if (_sameIdentity(chunks, ordered)) {
        final blankLine = _lineEnding(source) * 2;
        for (var i = 1; i < ordered.length; i++) {
          final previous = ordered[i - 1];
          final current = ordered[i];
          if (_groupKey(previous) == _groupKey(current)) continue;
          final currentStart = _leadingCommentStart(
            source,
            current.node.offset,
            bodyStart,
          );
          if (currentStart < previous.node.end) continue;
          final gap = source.substring(previous.node.end, currentStart);
          if (gap != blankLine) {
            edits.add(_Edit(previous.node.end, currentStart, blankLine));
          }
        }
        continue;
      }
      final originalBody = source.substring(bodyStart, bodyEnd);
      final leading = _leadingWhitespace(originalBody);
      final trailing = source.substring(sortableMembers.last.end, bodyEnd);
      final body = _joinMemberChunks(ordered, source);
      final replacement = '$leading$body$trailing';
      if (replacement != originalBody) {
        edits.add(_Edit(bodyStart, bodyEnd, replacement));
      }
    }
    return _applyEdits(source, edits);
  }

  List<_MemberChunk> _order(List<_MemberChunk> input) {
    final buckets = <String, List<_MemberChunk>>{};
    for (final chunk in input) {
      buckets.putIfAbsent(chunk.category, () => []).add(chunk);
    }
    final output = <_MemberChunk>[];
    for (final category in config.memberOrdering) {
      final values = buckets.remove(category) ?? <_MemberChunk>[];
      if (category == 'public-other-methods' &&
          !config.memberOrdering.contains('private-other-methods')) {
        values.addAll(
          buckets.remove('private-other-methods') ?? <_MemberChunk>[],
        );
        if (!config.sortOtherMethods) {
          values.sort((a, b) => a.originalIndex.compareTo(b.originalIndex));
        }
      }
      final shouldSort =
          (category != 'public-other-methods' &&
              category != 'private-other-methods') ||
          config.sortOtherMethods;
      if (config.groupAndSortGetterMethods &&
          (category == 'public-override-methods' ||
              category == 'public-other-methods' ||
              category == 'private-other-methods')) {
        final getters = values.where((value) => value.isGetter).toList()
          ..sort(_compareByName);
        final otherMethods = values.where((value) => !value.isGetter).toList();
        if (shouldSort) {
          otherMethods.sort(_compareByName);
        } else {
          otherMethods.sort(
            (a, b) => a.originalIndex.compareTo(b.originalIndex),
          );
        }
        values
          ..clear()
          ..addAll(getters)
          ..addAll(otherMethods);
      } else if (shouldSort) {
        if (config.groupAndSortVariableTypes &&
            category.endsWith('variables')) {
          values.sort((a, b) {
            final byType = a.typeName.toLowerCase().compareTo(
              b.typeName.toLowerCase(),
            );
            return byType == 0 ? _compareByName(a, b) : byType;
          });
        } else {
          values.sort(_compareByName);
        }
      }
      output.addAll(values);
    }
    // Unknown/future categories remain in their original relative order.
    final remaining = buckets.values.expand((e) => e).toList()
      ..sort((a, b) => a.originalIndex.compareTo(b.originalIndex));
    output.addAll(remaining);
    return output;
  }

  String _applyEdits(String source, List<_Edit> edits) {
    if (edits.isEmpty) return source;
    edits.sort((a, b) => a.start.compareTo(b.start));
    final output = StringBuffer();
    var cursor = 0;
    for (final edit in edits) {
      if (edit.start < cursor) {
        throw StateError('Source edits overlap.');
      }
      output
        ..write(source.substring(cursor, edit.start))
        ..write(edit.replacement);
      cursor = edit.end;
    }
    output.write(source.substring(cursor));
    return output.toString();
  }

  ({String category, String name, String typeName, bool isGetter}) _memberInfo(
    ClassMember member,
  ) {
    if (member is ConstructorDeclaration) {
      return (
        category: member.name == null
            ? 'public-constructor'
            : 'named-constructors',
        name: member.name?.lexeme ?? '',
        typeName: '',
        isGetter: false,
      );
    }
    if (member is FieldDeclaration) {
      final name = member.fields.variables.map((v) => v.name.lexeme).join('_');
      final isPrivate = name.startsWith('_');
      final category = _hasOverride(member)
          ? 'public-override-variables'
          : member.isStatic
          ? isPrivate
                ? 'private-static-variables'
                : 'public-static-variables'
          : isPrivate
          ? 'private-instance-variables'
          : 'public-instance-variables';
      return (
        category: category,
        name: name,
        typeName: member.fields.type?.toSource() ?? 'var',
        isGetter: false,
      );
    }
    if (member is MethodDeclaration) {
      final name = member.name.lexeme;
      final category = name == 'build' && !member.isGetter && !member.isSetter
          ? 'build-method'
          : _hasOverride(member)
          ? 'public-override-methods'
          : name.startsWith('_')
          ? 'private-other-methods'
          : 'public-other-methods';
      return (
        category: category,
        name: name,
        typeName: '',
        isGetter: member.isGetter,
      );
    }
    return (category: 'unclassified', name: '', typeName: '', isGetter: false);
  }

  bool _hasOverride(AnnotatedNode node) =>
      node.metadata.any((annotation) => annotation.name.name == 'override');
  bool _sameIdentity(List<_MemberChunk> a, List<_MemberChunk> b) {
    for (var i = 0; i < a.length; i++) {
      if (!identical(a[i].node, b[i].node)) return false;
    }
    return true;
  }

  int _compareByName(_MemberChunk a, _MemberChunk b) {
    final byName = a.name.toLowerCase().compareTo(b.name.toLowerCase());
    return byName == 0 ? a.originalIndex.compareTo(b.originalIndex) : byName;
  }

  String _joinMemberChunks(List<_MemberChunk> chunks, String source) {
    final newline = _lineEnding(source);
    final output = StringBuffer();
    for (var i = 0; i < chunks.length; i++) {
      if (i > 0) {
        final sameGroup = _groupKey(chunks[i - 1]) == _groupKey(chunks[i]);
        output.write(newline * (sameGroup ? 1 : 2));
      }
      output.write(chunks[i].source.trimRight());
    }
    return output.toString();
  }

  String _groupKey(_MemberChunk chunk) {
    var key = chunk.category;
    if (chunk.category == 'private-other-methods' &&
        !config.memberOrdering.contains('private-other-methods')) {
      key = 'public-other-methods';
    }
    if (config.groupAndSortGetterMethods &&
        (chunk.category == 'public-override-methods' ||
            chunk.category == 'public-other-methods' ||
            chunk.category == 'private-other-methods')) {
      key += chunk.isGetter ? ':getters' : ':methods';
    }
    if (config.groupAndSortVariableTypes &&
        chunk.category.endsWith('variables')) {
      key += ':${chunk.typeName.toLowerCase()}';
    }
    return key;
  }

  int _leadingCommentStart(String source, int offset, int lowerBound) {
    if (offset <= lowerBound) return offset;
    final lineStart = source.lastIndexOf('\n', offset - 1) + 1;
    var cursor = lineStart;
    while (cursor > lowerBound) {
      final previousEnd = cursor - 1;
      final previousStart = source.lastIndexOf('\n', previousEnd - 1) + 1;
      final line = source.substring(previousStart, previousEnd).trimLeft();
      if (line.startsWith('///') ||
          line.startsWith('//') ||
          line.startsWith('*') ||
          line.startsWith('/*') ||
          line.startsWith('*/')) {
        cursor = previousStart;
      } else if (line.trim().isEmpty) {
        // Keep one blank line with a doc-comment block, but don't consume
        // arbitrary whitespace separating unrelated declarations.
        break;
      } else {
        break;
      }
    }
    return cursor;
  }

  String _leadingWhitespace(String value) =>
      RegExp(r'^[\r\n]*').firstMatch(value)!.group(0)!;
  String _lineEnding(String source) => source.contains('\r\n') ? '\r\n' : '\n';
  String _declarationName(AstNode declaration) => switch (declaration) {
    final ClassDeclaration value => value.namePart.typeName.lexeme,
    final EnumDeclaration value => value.namePart.typeName.lexeme,
    final MixinDeclaration value => value.name.lexeme,
    _ => '',
  };
}

class _MemberChunk {
  const _MemberChunk(
    this.source,
    this.category,
    this.name,
    this.originalIndex,
    this.node, {
    this.typeName = '',
    this.isGetter = false,
  });

  final String category;
  final bool isGetter;
  final String name;
  final AstNode node;
  final int originalIndex;
  final String source;
  final String typeName;
}

class _Edit {
  const _Edit(this.start, this.end, this.replacement);

  final int end;
  final String replacement;
  final int start;
}
