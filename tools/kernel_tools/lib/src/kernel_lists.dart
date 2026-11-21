/// [items] as the list type of the parameter it is passed to: `List<E>` up to
/// Dart 3.13, an extension type on it from 3.14 (`DartTypeList`,
/// `ExpressionList`, `ConstantList`, `ConstantMapEntryList`). One source then
/// builds against either package:kernel; the cast checks only `List<E>`.
L kernelList<L, E>(List<E> items) => items as L;
