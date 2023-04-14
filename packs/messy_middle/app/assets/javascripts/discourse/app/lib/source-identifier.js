import getURL from "discourse-common/lib/get-url";
import PreloadStore from "discourse/lib/preload-store";
import { isDevelopment } from "discourse-common/config/environment";

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

  const themeMatches =
    error.stack.match(/\/theme-javascripts\/[\w-]+\.js/g) || [];

  for (const match of themeMatches) {
    const scriptElement = document.querySelector(`script[src*="${match}"`);
    if (scriptElement?.dataset.themeId) {
      return {
        type: "theme",
        ...getThemeInfo(scriptElement.dataset.themeId),
      };
    }
  }

  let plugin;

  // Source-mapped:
  plugin = plugin || error.stack.match(/plugins\/([\w-]+)\//)?.[1];

  if (isDevelopment()) {
    // Un-source-mapped:
    plugin = plugin || error.stack.match(/assets\/plugins\/([\w-]+)\.js/)?.[1];
  }

  // Production mode
  plugin =
    plugin ||
    error.stack.match(
      /assets\/plugins\/_?([\w-]+)-[0-9a-f]+(?:\.br)?\.js/
    )?.[1];

  if (plugin) {
    return {
      type: "plugin",
      name: plugin,
    };
  }
}

export function getThemeInfo(id) {
  const name = PreloadStore.get("activatedThemes")?.[id] || `(theme-id: ${id})`;
  return {
    id,
    name,
    path: getURL(`/admin/customize/themes/${id}?safe_mode=no_themes`),
  };
}

export function consolePrefix(error, source) {
  source = source || identifySource(error);
  if (source && source.type === "theme") {
    return `[THEME ${source.id} '${source.name}']`;
  } else if (source && source.type === "plugin") {
    return `[PLUGIN ${source.name}]`;
  }

  return "";
}
