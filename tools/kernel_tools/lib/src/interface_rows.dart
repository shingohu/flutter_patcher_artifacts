import 'package:kernel/kernel.dart';

import 'interface_document.dart';

/// The name a dynamic interface row gives [m], the one `LibraryIndex`
/// resolves it by: `get:` or `set:` and the name for a getter or setter
/// procedure, the bare name for every other member (fields, methods,
/// operators, constructors and factories).
String memberName(Member m) => m is Procedure && m.isGetter
    ? 'get:${m.name.text}'
    : m is Procedure && m.isSetter
    ? 'set:${m.name.text}'
    : m.name.text;

/// Whether `LibraryIndex` resolves [m] by its name, so a row can name it.
/// It indexes a private name only inside the library the name belongs to:
/// `_addListener` of riverpod's framework library resolves there, while a
/// private member a mixin application copies into another library does not.
///
/// This is the only test for members the host reaches on module instances
/// (inherited members, dispatch): host code calls its own privates by name.
/// Privates are skipped only where the module names a host member (its
/// calls, overrides, constants, compiler hints), as module source cannot
/// write another library's private name.
bool indexableMember(Member m) =>
    !m.name.isPrivate || m.name.library == m.enclosingLibrary;

/// Whether [lib] belongs to the app: a package named in [own], or a `file:` library.
bool isOwnLibrary(Library lib, Set<String> own) {
  final uri = lib.importUri;
  if (uri.scheme != 'package') return uri.scheme == 'file';
  return own.contains(uri.pathSegments.first);
}

/// [doc] with every row whose member name is shared by several members of
/// its class listed by the class instead.
///
/// The SDK resolves a row's member through `LibraryIndex`, which keeps one
/// member per [memberName] of a class and lets a later one replace an
/// earlier. Constructors are named apart from members in Dart but not
/// there: a field replaces a factory of its name, and a constructor
/// replaces a field or method of its name. A row naming the field
/// `CupertinoDesktopTextSelectionToolbarButton.text` resolved to the
/// constructor of that name and failed as not an instance member; a row
/// naming a factory beside a field of its name would resolve to the field
/// silently. A class row covers every member, so it is what the row meant.
InterfaceDocument conformRows(Component component, InterfaceDocument doc) {
  final shared = <String>{};
  for (final library in component.libraries) {
    for (final cls in library.classes) {
      final seen = <String>{};
      for (final m in [...cls.procedures, ...cls.fields, ...cls.constructors]) {
        if (!indexableMember(m)) continue;
        if (!seen.add(memberName(m))) {
          shared.add('${library.importUri} ${cls.name} ${memberName(m)}');
        }
      }
    }
  }
  if (shared.isEmpty) return doc;
  final result = InterfaceDocument();
  for (final section in InterfaceDocument.sections) {
    for (final row in doc.rows(section)) {
      final widen = shared.contains(
        '${row['library']} ${row['class']} ${row['member']}',
      );
      result.add(
        section,
        row['library']!,
        type: row['class'],
        member: widen ? null : row['member'],
      );
    }
  }
  return result;
}
