import 'dart:convert';
import 'dart:typed_data';
import 'package:kernel/kernel.dart';
import 'package:kernel/class_hierarchy.dart';
import 'package:kernel/core_types.dart';
import 'package:flutter_patcher_kernel_tools/src/kernel_lists.dart';
import 'package:flutter_patcher_kernel_tools/src/patch_checks.dart';

void main() {
  final file = Uri.parse('file:///fixture/main.dart');
  final host = Library(Uri.parse('package:host/api.dart'), fileUri: file);
  final app = Library(
    Uri.parse('package:patch.1.app/main.dart'),
    fileUri: file,
  );
  final cls = Class(name: 'Host', fileUri: file);
  final ctor = Constructor(
    FunctionNode(EmptyStatement()),
    name: Name(''),
    fileUri: file,
  );
  cls.addConstructor(ctor);
  host.addClass(cls);
  final factory = Procedure(
    Name('factory'),
    ProcedureKind.Factory,
    FunctionNode(EmptyStatement()),
    fileUri: file,
    isStatic: true,
  );
  cls.addProcedure(factory);
  final calls = [
    ExpressionStatement(
      ConstructorInvocation(ctor, Arguments(kernelList(<Expression>[])))..fileOffset = 3,
    ),
    ExpressionStatement(
      StaticInvocation(factory, Arguments(kernelList(<Expression>[])))..fileOffset = 5,
    ),
    ExpressionStatement(
      ConstantExpression(
        ListConstant(
          const DynamicType(),
          kernelList(<Constant>[
            InstanceConstant(cls.reference, kernelList(const <DartType>[]), {}),
          ]),
        ),
      )..fileOffset = 7,
    ),
    ExpressionStatement(ConstructorTearOff(ctor)..fileOffset = 9),
  ];
  app.addProcedure(
    Procedure(
      Name('main'),
      ProcedureKind.Method,
      FunctionNode(Block(calls)),
      isStatic: true,
      fileUri: file,
    )..fileOffset = 0,
  );
  final component = Component(libraries: [host, app]);
  component.uriToSource[file] = Source(
    [0, 16],
    Uint8List.fromList(utf8.encode('0123456789abcdef')),
    app.importUri,
    file,
  );
  final missing = AllocationCheck({host}, {});
  app.accept(missing);
  if (missing.issues.length != 3)
    throw StateError(
      'Expected new/constant/tearoff; factory must not be counted: ${missing.issues}',
    );
  if (missing.issues.any((r) => r['line'] != 1 || r['file'] != file.toString()))
    throw StateError('Source location missing');
  final safe = AllocationCheck({host}, {'package:host/api.dart::Host'});
  app.accept(safe);
  if (safe.issues.isNotEmpty) throw StateError('Allocated class rejected');
  final local = AllocationCheck({}, {});
  app.accept(local);
  if (local.issues.isNotEmpty)
    throw StateError('Module class mistaken for host');
  print(
    'PASS allocation sites, constant graph, factory semantics and locations',
  );
  inheritedPrivates();
}

// Issue #17: the host calls its own private members by name on a module
// class's instances, so they are checked like public ones.
void inheritedPrivates() {
  final file = Uri.parse('file:///fixture/main.dart');
  Library library(String uri) => Library(Uri.parse(uri), fileUri: file);
  Procedure method(Name name) => Procedure(
    name,
    ProcedureKind.Method,
    FunctionNode(EmptyStatement()),
    fileUri: file,
  );
  final core = library('dart:core');
  final object = Class(name: 'Object', fileUri: file);
  core.addClass(object);
  final host = library('package:host/api.dart');
  final base = Class(
    name: 'Base',
    fileUri: file,
    supertype: Supertype(object, kernelList(const <DartType>[])),
  )
    ..addProcedure(method(Name('_listen', host)))
    ..addProcedure(method(Name('read')));
  host.addClass(base);
  final app = library('package:patch.1.app/main.dart');
  app.addClass(
    Class(
      name: 'Sub',
      fileUri: file,
      supertype: Supertype(base, kernelList(const <DartType>[])),
    ),
  );
  final component = Component(libraries: [core, host, app]);
  final hierarchy = ClassHierarchy(component, CoreTypes(component));
  List<Map<String, Object?>> check(List<String> members) => inheritedCheck(
    component,
    hierarchy,
    {core, host},
    [app],
    [
      'callable:',
      for (final m in members)
        '  - library: "package:host/api.dart"\n    class: Base\n    member: $m',
    ].join('\n'),
    jsonEncode({
      'callable': [
        for (final m in members)
          {'library': 'package:host/api.dart', 'class': 'Base', 'member': m},
      ],
    }),
  );
  final missing = check(['read']);
  if (missing.length != 1 || !'${missing.single}'.contains('Base._listen'))
    throw StateError('Unlisted inherited private passed: $missing');
  final listed = check(['read', '_listen']);
  if (listed.isNotEmpty)
    throw StateError('Listed inherited private rejected: $listed');
  print('PASS inherited private host members are checked');
}
