import { common, createLowlight } from "lowlight";
import { createHighlightPlugin } from "prosemirror-highlight";
import { createParser } from "prosemirror-highlight/lowlight";

export function createHighlight() {
  const lowlight = createLowlight(common);
  const parser = createParser(lowlight);

  return createHighlightPlugin({
    parser,
    languageExtractor: (node) => node.attrs.params,
  });
}
