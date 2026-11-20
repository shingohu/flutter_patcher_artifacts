// 1 · void main() => runApp(X())
import 'package:flutter/material.dart';
import 'common.dart';

void main() => runApp(const App());

// A dynamic `.text` access makes every framework member named text
// dynamically callable, among them the field
// CupertinoDesktopTextSelectionToolbarButton.text, which a constructor of
// its name shadows (issue #14). The interface smoke validates against it.
Object? dynamicText(dynamic value) => value.text;
