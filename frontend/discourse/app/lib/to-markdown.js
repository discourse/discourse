import { DOMParser as ProseMirrorDOMParser } from "prosemirror-model";
import { createSchema } from "../static/prosemirror/core/schema";
import Serializer from "../static/prosemirror/core/serializer";
import { transformWordListsHtml } from "../static/prosemirror/extensions/word-paste";
import { isBoundary } from "../static/prosemirror/lib/plugin-utils";
import {
  areDefaultExtensionsRegistered,
  getExtensions,
  markDefaultExtensionsRegistered,
  registerRichEditorExtension,
} from "./composer/rich-editor-extensions";

function ensureDefaultExtensions() {
  if (areDefaultExtensionsRegistered()) {
    return;
  }

  try {
    if (typeof require !== "undefined" && typeof require.has === "function") {
      const modulePath =
        "discourse/static/prosemirror/extensions/register-default";

      if (require.has(modulePath)) {
        const defaultExtensions = require(modulePath).default;

        if (!areDefaultExtensionsRegistered()) {
          defaultExtensions.forEach(registerRichEditorExtension);
          markDefaultExtensionsRegistered();
        }
      }
    }
  } catch {
    // require not available or module not found
  }
}

// Deprecated no-ops - kept for backward compatibility
function deprecationWarning(name) {
  // eslint-disable-next-line no-console
  console.warn(
    `${name} is deprecated. Use api.registerRichEditorExtension() instead.`
  );
}

export function addTagDecorateCallback() {
  deprecationWarning("addTagDecorateCallback");
}
export function addBlockDecorateCallback() {
  deprecationWarning("addBlockDecorateCallback");
}
export function addTextDecorateCallback() {
  deprecationWarning("addTextDecorateCallback");
}
export function clearTagDecorateCallbacks() {}
export function clearBlockDecorateCallbacks() {}
export function clearTextDecorateCallbacks() {}

export default function toMarkdown(html) {
  try {
    ensureDefaultExtensions();
    const extensions = getExtensions();
    const schema = createSchema(extensions);
    const domParser = ProseMirrorDOMParser.fromSchema(schema);
    const pluginParams = { utils: { isBoundary } };
    const serializer = new Serializer(extensions, pluginParams);

    const processedHtml = transformWordListsHtml(html);
    const element = new DOMParser().parseFromString(processedHtml, "text/html");

    for (const ext of extensions) {
      if (typeof ext.transformParsedHTML === "function") {
        try {
          ext.transformParsedHTML(element);
        } catch (e) {
          // eslint-disable-next-line no-console
          console.warn(
            `toMarkdown: transformParsedHTML failed for extension ${ext.name || ext.id || "(unknown)"}`,
            e
          );
        }
      }
    }

    const doc = domParser.parse(element);

    return serializer.convert(doc).trim();
  } catch {
    return "";
  }
}
