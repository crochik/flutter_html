# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project

`flutter_html` renders HTML and CSS as native Flutter widgets — not a webview. The core package plus seven
optional extension packages live in one repo, versioned in lockstep (all at the same version number).

## Toolchain and commands

Pinned to the Flutter revision in `.metadata`. In Claude Code on the web, `.claude/hooks/session-start.sh`
installs it and puts it on `PATH` automatically; the hook is a no-op locally, so bring your own Flutter.

The repo is a **Dart pub workspace**, so one resolve at the root covers all nine packages:

```bash
flutter pub get                      # resolves every package; also installs the pinned Melos
```

Melos is a dev_dependency, not a global install, so always invoke it via `dart run`:

```bash
dart run melos list                  # the nine workspace packages
dart run melos run analyze           # flutter analyze --fatal-infos in every package
dart run melos run test              # every package that has a test/ dir
dart run melos run format            # apply dart format
dart run melos run format:check      # verify formatting (CI gate)
dart run melos run gen_coverage      # combine per-package lcov into coverage_report/
```

Running a single test — note `--no-pub`, since the workspace is already resolved:

```bash
flutter test --no-pub test/whitespace_test.dart
flutter test --no-pub test/whitespace_test.dart --plain-name "test that extra newlines"
cd packages/flutter_html_svg && flutter test --no-pub   # a sub-package's suite
```

`flutter analyze` and `flutter test` at the repo root cover only the core package; use the Melos scripts to
hit all nine.

### Melos 8 configuration gotcha

There is no `melos.yaml` — Melos 7+ removed it. Configuration lives under the `melos:` key in the **root
`pubspec.yaml`**, with `useRootAsPackage: true` because the root pubspec is itself the `flutter_html`
package. Workspace membership comes from the pubspec's `workspace:` list, and every member declares
`resolution: workspace`. Scripts that fan out across packages use the Melos 8 `exec: {command: ...}` schema,
not the older `run: melos exec -- ...` form (a nested bare `melos` is not on `PATH`).

Adding a package means: create it under `packages/`, add `resolution: workspace` to its pubspec, and add it
to the root `workspace:` list.

## Architecture

### The five-stage pipeline

`HtmlParser` (`lib/src/html_parser.dart`) is the heart of the package. `_HtmlParserState.prepareTree()` runs
four stages in `didChangeDependencies`, and the fifth in `build`. Understanding this ordering explains most
of the codebase:

1. **Prepare** — walk the `html` package's DOM and build a `StyledElement` tree. Each node is handed to
   `prepareFromExtension`, which picks exactly one handler for it.
2. **Style** — `beforeStyle` extension hook, then `styleTree()` cascades CSS.
3. **Process** — `beforeProcessing` extension hook, then `processTree()`.
4. **Build** — `buildTree()` converts `StyledElement`s into an `InlineSpan` tree via `buildFromExtension`.
5. **Render** — the spans go into a `CssBoxWidget`, which is where CSS box-model layout actually happens.

`processTree()` runs its five passes in a fixed, meaningful order: whitespace collapsing → relative value
resolution (`em`/`rem`/percentages) → list markers and counters → `::before`/`::after` generated content →
margin collapsing. Each lives in `lib/src/processing/`. Reordering them breaks CSS semantics — e.g. relative
sizes must resolve before margins can collapse.

The style cascade in `_styleTreeRecursive` applies, in order: `<style>` tag declarations, then the inline
`style` attribute, then the user's `style` map from the `Html` widget (so user styles always win). It then
recurses, passing only inheritable properties down via `Style.copyOnlyInherited`.

### Extensions are the whole extensibility story

Everything, including built-in tag support, is an `HtmlExtension`
(`lib/src/extension/html_extension.dart`). An extension declares `supportedTags` and optionally overrides
`matches`, `prepare`, `beforeStyle`, `beforeProcessing`, `build`, and `onDispose`.

Resolution order matters and is the same in `prepareFromExtension` and `buildFromExtension`: **user-supplied
extensions are tried first, in list order, then `HtmlParser.builtIns`, and the first match wins.** That is
how a user extension overrides built-in behavior for a tag. If nothing matches, prepare yields an
`EmptyContentElement` and build yields an empty `TextSpan` — a tag silently disappearing usually means no
extension claimed it.

`HtmlParser.builtIns` is order-sensitive too: the broad `StyledElementBuiltIn` and `TextBuiltIn` sit last so
that narrower built-ins (image, ruby, details, interactive) get first refusal.

### Tree element types

`StyledElement` is the base. `ReplacedElement` marks content Flutter renders itself rather than as styled
text, and its subclasses (`TextContentElement`, `LinebreakContentElement`, `EmptyContentElement`,
`RubyElement`) carry the special cases. `InteractiveElement` adds tap handling; `ImageElement` extends it.

`StyledElement.matchesSelector` powers CSS selector matching. It parses the selector with `csslib` and
evaluates it with `SelectorEvaluator` from `package:html/src/query_selector.dart` — an
`implementation_imports` violation that is deliberately suppressed, because that class has no public export.
It is the one place the package depends on `html` internals, so it is the first thing to check after an
`html` package upgrade.

### The optional packages

`packages/flutter_html_{audio,iframe,math,svg,table,video}` each wrap a third-party plugin behind an
`HtmlExtension`; `flutter_html_all` just re-exports the rest. They are opt-in so the core package stays
dependency-light — keep native plugin dependencies out of the core package.

`flutter_html_iframe` has platform-conditional implementations. The web one must use `dart:ui_web` for
`platformViewRegistry`, and the conditional import keys off `dart.library.js_interop` rather than
`dart.library.html` — the latter is false under Wasm, which silently selects the "unsupported" stub.

## Testing

`test/test_utils.dart` provides the harness. `generateStyledElementTreeFromHtml` pumps an `Html` widget and
returns the `StyledElement` tree, with `applyStyleSteps` and `applyProcessingSteps` letting you snapshot the
tree **partway through the pipeline** — that is how the styling and processing stages are tested in
isolation. `testData` in the same file is a tag-name-to-HTML map driving the broad smoke tests.

Be aware that `test/golden_test.dart` never actually compares images: its `matchesGoldenFile` call is
commented out, so those tests only assert the widget builds. Don't read a passing golden test as a visual
regression check.

Widget tests exercise real Flutter layout and semantics, so framework upgrades surface here first — a
semantics assertion from `RenderParagraph`'s sibling merge groups usually means a `WidgetSpan` child needs
its own `Semantics(container: true)` boundary.

## Example app

`example/` is a workspace member, so `flutter pub get` at the root resolves it too. Its iOS and macOS
projects use **Swift Package Manager**, which is the Flutter default — there are no Podfiles, and there
should not be. All platform directories are stock Flutter template output apart from two deliberate edits:
the Android `INTERNET` permission and the macOS network-client entitlement, both needed because the example
loads network images, video and web content. Regenerating a platform directory means re-applying those.
