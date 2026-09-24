import { waitForPromise } from "@ember/test-waiters";
import deprecated from "discourse/lib/deprecated";

// Deprecated no-ops - kept for backward compatibility
function deprecationWarning(name) {
  deprecated(
    `${name} is deprecated. Use api.registerRichEditorExtension() instead.`,
    {
      id: `discourse.to-markdown.${name}`,
      since: "2026.5.0",
    }
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
export function clearTagDecorateCallbacks() {
  deprecationWarning("clearTagDecorateCallbacks");
}
export function clearBlockDecorateCallbacks() {
  deprecationWarning("clearBlockDecorateCallbacks");
}
export function clearTextDecorateCallbacks() {
  deprecationWarning("clearTextDecorateCallbacks");
}

/**
 * Converts HTML to markdown.
 *
 * The conversion itself lives under `static/`, which the build leaves out of
 * the app bundle, so everything it needs is imported there rather than through
 * an `import()` of its own. One split point, fetched on the first conversion.
 *
 * @param {string} html
 * @returns {Promise<string>} the markdown, or an empty string if it could not
 *   be converted
 */
export default async function toMarkdown(html) {
  try {
    const { default: convert } = await waitForPromise(
      import(
        /* dynamicChunkName: "to-markdown" */ "discourse/static/prosemirror/to-markdown"
      )
    );

    return convert(html);
  } catch (e) {
    // eslint-disable-next-line no-console
    console.error("toMarkdown failed:", e);
    return "";
  }
}
