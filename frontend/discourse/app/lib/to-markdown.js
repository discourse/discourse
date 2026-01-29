import { DOMParser as ProseMirrorDOMParser } from "prosemirror-model";
import { createSchema } from "../static/prosemirror/core/schema";
import Serializer from "../static/prosemirror/core/serializer";
import { transformWordListsHtml } from "../static/prosemirror/extensions/word-paste";
import { isBoundary } from "../static/prosemirror/lib/plugin-utils";
import {
  getExtensions,
  registerRichEditorExtension,
} from "./composer/rich-editor-extensions";

let defaultExtensionsLoaded = false;

// Synchronous check and load of default extensions
// Uses require() if the module is already loaded, otherwise does nothing
// (extensions will be loaded by resetRichEditorExtensions in tests or prosemirror-editor in app)
function ensureDefaultExtensions() {
  // Skip if defaults were already loaded by us, or if any extensions are already registered
  // (e.g., by prosemirror-editor or after resetRichEditorExtensions)
  if (defaultExtensionsLoaded || getExtensions().length > 0) {
    return;
  }

  // Try to load default extensions synchronously if they're already bundled
  try {
    if (typeof require !== "undefined" && typeof require.has === "function") {
      const modulePath =
        "discourse/static/prosemirror/extensions/register-default";

      if (require.has(modulePath)) {
        const extensions = require(modulePath).default;
        extensions.forEach(registerRichEditorExtension);
        defaultExtensionsLoaded = true;
      }
    }
  } catch {
    // Silently ignore if require is not available or module not found
  }
}

// Legacy callback system - deprecated, kept for backward compatibility
// These callbacks are no longer invoked by toMarkdown() which now uses ProseMirror.
// Use api.registerRichEditorExtension() instead.
let tagDecorateCallbacks = [];
let blockDecorateCallbacks = [];
let textDecorateCallbacks = [];

let hasWarnedTag = false;
let hasWarnedBlock = false;
let hasWarnedText = false;

/**
 * @deprecated This callback is no longer invoked. Use api.registerRichEditorExtension() instead.
 * See: https://meta.discourse.org/t/developing-prose-mirror-rich-editor-extensions/
 */
export function addTagDecorateCallback(callback) {
  if (!hasWarnedTag) {
    // eslint-disable-next-line no-console
    console.warn(
      "addTagDecorateCallback is deprecated and no longer invoked. " +
        "Use api.registerRichEditorExtension() instead. " +
        "See: https://meta.discourse.org/t/developing-prose-mirror-rich-editor-extensions/"
    );
    hasWarnedTag = true;
  }
  tagDecorateCallbacks.push(callback);
}

export function clearTagDecorateCallbacks() {
  tagDecorateCallbacks = [];
}

/**
 * @deprecated This callback is no longer invoked. Use api.registerRichEditorExtension() instead.
 * See: https://meta.discourse.org/t/developing-prose-mirror-rich-editor-extensions/
 */
export function addBlockDecorateCallback(callback) {
  if (!hasWarnedBlock) {
    // eslint-disable-next-line no-console
    console.warn(
      "addBlockDecorateCallback is deprecated and no longer invoked. " +
        "Use api.registerRichEditorExtension() instead. " +
        "See: https://meta.discourse.org/t/developing-prose-mirror-rich-editor-extensions/"
    );
    hasWarnedBlock = true;
  }
  blockDecorateCallbacks.push(callback);
}

export function clearBlockDecorateCallbacks() {
  blockDecorateCallbacks = [];
}

/**
 * @deprecated This callback is no longer invoked. Use api.registerRichEditorExtension() instead.
 * See: https://meta.discourse.org/t/developing-prose-mirror-rich-editor-extensions/
 */
export function addTextDecorateCallback(callback) {
  if (!hasWarnedText) {
    // eslint-disable-next-line no-console
    console.warn(
      "addTextDecorateCallback is deprecated and no longer invoked. " +
        "Use api.registerRichEditorExtension() instead. " +
        "See: https://meta.discourse.org/t/developing-prose-mirror-rich-editor-extensions/"
    );
    hasWarnedText = true;
  }
  textDecorateCallbacks.push(callback);
}

export function clearTextDecorateCallbacks() {
  textDecorateCallbacks = [];
}

export default function toMarkdown(html) {
  try {
    ensureDefaultExtensions();
    const extensions = getExtensions();
    const schema = createSchema(extensions);
    const domParser = ProseMirrorDOMParser.fromSchema(schema);
    const pluginParams = { utils: { isBoundary } };
    const serializer = new Serializer(extensions, pluginParams);

    // Transform Word list HTML to standard list structure
    const processedHtml = transformWordListsHtml(html);
    const element = new DOMParser().parseFromString(processedHtml, "text/html");

    // Apply extension-provided DOM transforms before parsing
    // Each transform is wrapped in try/catch so a faulty extension doesn't blank the entire conversion
    for (const ext of extensions) {
      if (typeof ext.transformParsedHTML === "function") {
        try {
          ext.transformParsedHTML(element);
        } catch (e) {
          // eslint-disable-next-line no-console
          console.warn(
            "toMarkdown: transformParsedHTML failed for extension",
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
