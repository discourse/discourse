import { warn } from "@ember/debug";
import { waitForPromise } from "@ember/test-waiters";

/**
 * Named shortcuts for a code editor's language support.
 *
 * A shortcut resolves to CodeMirror extensions, so it can carry anything a
 * language needs — highlighting, indentation, its own completions — while
 * callers stay free to append more through the editor's `extensions` argument.
 *
 * The built-in set loads on demand; plugins add their own with
 * {@link registerCodemirrorLanguage}.
 */

const BUILT_IN = {
  css: () => import("discourse/static/codemirror/languages/css"),
  html: () => import("discourse/static/codemirror/languages/html"),
  javascript: () => import("discourse/static/codemirror/languages/javascript"),
  json: () => import("discourse/static/codemirror/languages/json"),
  scss: () => import("discourse/static/codemirror/languages/scss"),
  sql: () => import("discourse/static/codemirror/languages/sql"),
  yaml: () => import("discourse/static/codemirror/languages/yaml"),
};

const registered = new Map();

/**
 * Registers a language shortcut.
 *
 * @param {string} name identifier passed to an editor's `language` argument
 * @param {() => Promise<{ default: (cmParams: object) => unknown }>} loader
 *   resolves to a module whose default export builds the extensions
 */
export function registerCodemirrorLanguage(name, loader) {
  // Taking a name that already resolves is allowed — a plugin may have a
  // better grammar for it — but it is worth saying so, since two plugins
  // claiming one name would otherwise silently come down to load order.
  if (registered.has(name) || BUILT_IN[name]) {
    warn(`The CodeMirror language "${name}" was already registered.`, {
      id: "discourse.codemirror-language-override",
    });
  }

  registered.set(name, loader);
}

/**
 * Resolves a language shortcut to its extension builder.
 *
 * @param {string} name
 * @returns {Promise<((cmParams: object) => unknown) | null>} null when the
 *   name is unknown, so an editor can fall back to plain text
 */
export async function loadCodemirrorLanguage(name) {
  const loader = registered.get(name) || BUILT_IN[name];
  if (!loader) {
    warn(`Unknown CodeMirror language "${name}".`, {
      id: "discourse.codemirror-language-missing",
    });
    return null;
  }

  return (await waitForPromise(loader())).default;
}

export function codemirrorLanguageNames() {
  return [...new Set([...Object.keys(BUILT_IN), ...registered.keys()])].sort();
}

export function clearRegisteredCodemirrorLanguages() {
  registered.clear();
}
