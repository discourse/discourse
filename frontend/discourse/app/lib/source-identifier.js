import { DEBUG } from "@glimmer/env";
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

  let plugin;

  // Build patterns array dynamically to match plugin files in both development and production
  // Order matters: check more specific patterns (_admin) before general ones
  const patterns = [];

  if (DEBUG) {
    patterns.push(
      /assets\/plugins\/([\w-]+)_admin\.js/, // Admin UI Development (no fingerprinting)
      /assets\/plugins\/([\w-]+)\.js/, // Development (no fingerprinting)
      /assets\/plugins\/test\/([\w-]+)_tests\.js/ // Test files
    );
  }

  patterns.push(
    /assets\/plugins\/_?([\w-]+)-[0-9a-f]+_admin(?:\.(?:br|gz))?\.js/, // Admin UI Production (with fingerprints)
    /assets\/plugins\/_?([\w-]+)-[0-9a-f]+(?:\.(?:br|gz))?\.js/ // Production (with fingerprints)
  );

  for (const pattern of patterns) {
    plugin = stack.match(pattern)?.[1];
    if (plugin) {
      break;
    }
  }

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
  } else if (source && source.type === "browser-extension") {
    return "[BROWSER EXTENSION]";
  }

  return "";
}
