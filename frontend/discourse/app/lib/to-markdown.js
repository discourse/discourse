import deprecated from "discourse/lib/deprecated";
import {
  areDefaultExtensionsRegistered,
  getExtensions,
} from "./composer/rich-editor-extensions";

async function ensureDefaultExtensions() {
  if (areDefaultExtensionsRegistered()) {
    return;
  }

  // The module's side effect registers the defaults and marks them as registered
  await import(
    /* dynamicChunkName: "prosemirror-extensions" */ "discourse/static/prosemirror/extensions/register-default"
  );
}

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

export default async function toMarkdown(html) {
  try {
    await ensureDefaultExtensions();

    const [
      { DOMParser: ProseMirrorDOMParser },
      { createSchema },
      { default: Serializer },
      { transformWordHtml },
      { isBoundary },
    ] = await Promise.all([
      import("prosemirror-model"),
      import(
        /* dynamicChunkName: "prosemirror-schema" */ "discourse/static/prosemirror/core/schema"
      ),
      import(
        /* dynamicChunkName: "prosemirror-serializer" */ "discourse/static/prosemirror/core/serializer"
      ),
      import("discourse/static/prosemirror/extensions/word-paste"),
      import("discourse/static/prosemirror/lib/plugin-utils"),
    ]);

    const extensions = getExtensions();
    const schema = createSchema(extensions);
    const domParser = ProseMirrorDOMParser.fromSchema(schema);
    const pluginParams = { utils: { isBoundary } };
    const serializer = new Serializer(extensions, pluginParams);

    const processedHtml = transformWordHtml(html);
    const parsedDoc = new DOMParser().parseFromString(
      processedHtml,
      "text/html"
    );

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

    const doc = domParser.parse(parsedDoc);

    return serializer.convert(doc).trim();
  } catch (e) {
    // eslint-disable-next-line no-console
    console.error("toMarkdown failed:", e);
    return "";
  }
}
