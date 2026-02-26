import {
  areDefaultExtensionsRegistered,
  getExtensions,
} from "./composer/rich-editor-extensions";

async function ensureDefaultExtensions() {
  if (areDefaultExtensionsRegistered()) {
    return;
  }

  // The module's side effect registers the defaults and marks them as registered
  await import("discourse/static/prosemirror/extensions/register-default");
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

export default async function toMarkdown(html) {
  try {
    await ensureDefaultExtensions();

    const [
      { DOMParser: ProseMirrorDOMParser },
      { createSchema },
      { default: Serializer },
      { transformWordListsHtml },
      { isBoundary },
    ] = await Promise.all([
      import("prosemirror-model"),
      import("discourse/static/prosemirror/core/schema"),
      import("discourse/static/prosemirror/core/serializer"),
      import("discourse/static/prosemirror/extensions/word-paste"),
      import("discourse/static/prosemirror/lib/plugin-utils"),
    ]);

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
