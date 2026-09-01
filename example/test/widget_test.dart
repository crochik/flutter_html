import 'package:example/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:flutter_html_all/flutter_html_all.dart';
import 'package:flutter_test/flutter_test.dart';

/// Pumps [child] and returns any errors the rendering pipeline reported.
Future<List<FlutterErrorDetails>> renderErrors(
  WidgetTester tester,
  Widget child,
) async {
  final errors = <FlutterErrorDetails>[];
  final previous = FlutterError.onError;
  FlutterError.onError = errors.add;
  await tester.pumpWidget(child);
  await tester.pump();
  FlutterError.onError = previous;
  return errors;
}

void main() {
  testWidgets('the example page renders without layout exceptions', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 3000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    expect(await renderErrors(tester, const MyApp()), isEmpty);
  });

  // An <img> inside a <table> used to bring down the whole render tree in
  // debug builds. Table layout sizes its rows intrinsically, which makes
  // Flutter ask the baseline-aligned image placeholder for a dry baseline;
  // RenderImage does not implement computeDryBaseline and its default
  // implementation throws.
  testWidgets('an image inside a table renders without layout exceptions', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 3000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final errors = await renderErrors(
      tester,
      MaterialApp(
        home: Scaffold(
          body: Html(
            data:
                '<table><tr><td><img src="https://example.com/a.png" /></td></tr></table>',
            extensions: const [TableHtmlExtension()],
          ),
        ),
      ),
    );

    expect(errors, isEmpty);
  });
}
