import getURL from "discourse/lib/get-url";
import PreloadStore from "discourse/lib/preload-store";

const BROWSER_EXTENSION_PROTOCOLS = [
  "moz-extension://",
  "chrome-extension://",
  "webkit-masked-url://",
];

export default function identifySource(error) {
  if (!error || !error.stack) {
    try {
      throw new Error("Source identification error");
    } catch (e) {
      error = e;
    }
  }

  if (!error.stack) {
    return;
  }

  // Ignore the discourse-deprecation-collector plugin because it inserts itself
  // into all deprecation stacks.
  const stack = error.stack.replaceAll(
    /^.*discourse-deprecation-collector.*$/gm,
    ""
  );

  if (BROWSER_EXTENSION_PROTOCOLS.some((p) => stack.includes(p))) {
    return {
      type: "browser-extension",
    };
  }

  const themeMatches = stack.match(/\/theme-javascripts\/[\w-]+\.js/g) || [];

  for (const match of themeMatches) {
    const scriptElement = document.querySelector(
      `script[src*="${match}"], link[rel="modulepreload"][href*="${match}"]`
    );
    if (scriptElement?.dataset.themeId) {
      return {
        type: "theme",
        ...getThemeInfo(scriptElement.dataset.themeId),
      };
    }
  }

  const plugin = stack.match(/assets\/(?:js|br|gz)\/plugins\/([\w-]+)_/)?.[1];

  if (plugin) {
    return {
      type: "plugin",
      name: plugin,
    };
  }
}

export function getThemeInfo(id) {
  const name =
    PreloadStore.get("activatedThemes")?.[id]?.name || `(theme-id: ${id})`;
  return {
    id,
    name,
    path: getURL(`/admin/customize/themes/${id}?safe_mode=no_themes`),
  };
}

/**
 * Maps a plugin API's customization source to the shape `deprecated()` and its admin notice
 * expect, which identify a theme by name and settings path rather than by id alone.
 *
 * @param {import("discourse/lib/customization-source").CustomizationSource} [source]
 * @returns {{ type: string, name: string, id?: number, path?: string } | undefined} `undefined`
 *   for core, so callers fall back to identifying the source from the stack.
 */
export function noticeSourceFor(source) {
  if (source?.type === "plugin") {
    return { type: "plugin", name: source.name };
  }

  if (source?.type === "theme") {
    return { type: "theme", ...getThemeInfo(source.id) };
  }
}

export function consolePrefix(error, source) {
  source = source || identifySource(error);
  if (source && source.type === "theme") {
    return `[THEME ${source.id} '${source.name}']`;
  } else if (source && source.type === "plugin") {
    return `[PLUGIN ${source.name}]`;
  } else if (source && source.type === "browser-extension") {
    return "[BROWSER EXTENSION]";
  }

  return "";
}
