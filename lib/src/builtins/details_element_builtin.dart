import 'package:flutter/material.dart';
import 'package:flutter_html/flutter_html.dart';

/// The [DetailsElementBuiltIn] handles the default rendering for the
/// `<details>` html tag
class DetailsElementBuiltIn extends HtmlExtension {
  const DetailsElementBuiltIn();

  @override
  Set<String> get supportedTags => {"details"};

  @override
  StyledElement prepare(
    ExtensionContext context,
    List<StyledElement> children,
  ) {
    return StyledElement(
      name: context.elementName,
      children: children,
      style: Style(),
      node: context.node,
    );
  }

  @override
  InlineSpan build(ExtensionContext context) {
    final childList = context.builtChildrenMap!;
    final children = childList.values;

    InlineSpan? firstChild = children.isNotEmpty ? children.first : null;
    return WidgetSpan(
      // The `<details>` element renders as an [ExpansionTile], whose semantics
      // are incompatible with those of the text fragments it sits next to in
      // the enclosing paragraph. Marking it as its own semantics container
      // keeps it out of the paragraph's sibling merge group, while
      // `explicitChildNodes` preserves the tile's own tappable/expandable
      // semantics instead of flattening them into a single label.
      child: Semantics(
        container: true,
        explicitChildNodes: true,
        child: ExpansionTile(
          key: AnchorKey.of(context.parser.key, context.styledElement!),
          expandedAlignment: Alignment.centerLeft,
          title:
              childList.keys.isNotEmpty &&
                  childList.keys.first.name == "summary"
              ? CssBoxWidget.withInlineSpanChildren(
                  children: firstChild == null ? [] : [firstChild],
                  style: context.styledElement!.style,
                )
              : const Text("Details"),
          children: [
            CssBoxWidget.withInlineSpanChildren(
              children:
                  childList.keys.isNotEmpty &&
                      childList.keys.first.name == "summary"
                  ? children.skip(1).toList()
                  : children.toList(),
              style: context.styledElement!.style,
            ),
          ],
        ),
      ),
    );
  }
}
