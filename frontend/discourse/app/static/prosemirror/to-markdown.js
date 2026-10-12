// Registers the default extensions as a side effect.
import "./extensions/register-default";
import { DOMParser as ProseMirrorDOMParser } from "prosemirror-model";
import { getExtensions } from "discourse/lib/composer/rich-editor-extensions";
import { createSchema } from "./core/schema";
import Serializer from "./core/serializer";
import { transformWordHtml } from "./extensions/word-paste";
import { isBoundary } from "./lib/plugin-utils";

// Chrome and Safari copy the space next to an inline element as a non-breaking
// space, which stops a pasted emoji from cooking. Restore just the copy
// artifact - a lone nbsp in a bare span - so an author's own nbsp is kept.
function restoreReplacedSpaces(root) {
  const spans = root.querySelectorAll(
    "span:not([class]):not([style]), span.Apple-converted-space"
  );
  for (const span of spans) {
    if (span.childNodes.length === 1 && span.textContent === "\u00a0") {
      span.replaceWith(root.ownerDocument.createTextNode(" "));
    }
  }
}

export default function toMarkdown(html) {
  const extensions = getExtensions();
  const schema = createSchema(extensions);
  const domParser = ProseMirrorDOMParser.fromSchema(schema);
  const pluginParams = { utils: { isBoundary } };
  const serializer = new Serializer(extensions, pluginParams);

  const processedHtml = transformWordHtml(html);
  const parsedDoc = new DOMParser().parseFromString(processedHtml, "text/html");

  restoreReplacedSpaces(parsedDoc.body);

  for (const ext of extensions) {
    if (typeof ext.transformParsedHTML === "function") {
      try {
        ext.transformParsedHTML(parsedDoc);
      } catch (e) {
        // eslint-disable-next-line no-console
        console.warn(
          `toMarkdown: transformParsedHTML failed for extension ${ext.name || ext.id || "(unknown)"}`,
          e
        );
      }
    }
  }

  return serializer.convert(domParser.parse(parsedDoc)).trim();
}
