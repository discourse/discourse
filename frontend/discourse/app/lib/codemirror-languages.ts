import { warn } from "@ember/debug";
import { waitForPromise } from "@ember/test-waiters";
import type { Extension } from "@codemirror/state";

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

/**
 * What every extension builder receives. Plugins cannot import CodeMirror
 * themselves, so the modules arrive here instead.
 */
export interface CodemirrorParams {
  /** The `@codemirror/autocomplete` module. */
  cmAutocomplete: typeof import("@codemirror/autocomplete");
  /** The `@codemirror/language` module. */
  cmLanguage: typeof import("@codemirror/language");
  /** The `@codemirror/state` module. */
  cmState: typeof import("@codemirror/state");
  /** The `@codemirror/view` module. */
  cmView: typeof import("@codemirror/view");
  /** The `@lezer/highlight` module, for styling a grammar's tokens. */
  lezerHighlight: typeof import("@lezer/highlight");
  /** Helpers for building expression editors on top of the base editor. */
  utils: (typeof import("discourse/static/codemirror/expression-utils"))["expressionUtils"];
}

/**
 * Builds the extensions an editor's `extensions` argument adds on top of the
 * language.
 */
export type CodemirrorExtensionBuilder = (
  params: CodemirrorParams
) => readonly Extension[];

/**
 * Builds a language's extensions. `options` is whatever the editor was given
 * as `languageOptions`, so a language decides its own configuration shape.
 */
export type CodemirrorLanguageBuilder<Options extends object = object> = (
  params: CodemirrorParams,
  options?: Options
) => Extension;

/** Resolves to a module whose default export builds the language. */
export type CodemirrorLanguageLoader = () => Promise<{
  default: CodemirrorLanguageBuilder;
}>;

const BUILT_IN: Record<string, CodemirrorLanguageLoader> = {
  css: () => import("discourse/static/codemirror/languages/css"),
  html: () => import("discourse/static/codemirror/languages/html"),
  javascript: () => import("discourse/static/codemirror/languages/javascript"),
  json: () => import("discourse/static/codemirror/languages/json"),
  scss: () => import("discourse/static/codemirror/languages/scss"),
  sql: () => import("discourse/static/codemirror/languages/sql"),
  yaml: () => import("discourse/static/codemirror/languages/yaml"),
};

const registered = new Map<string, CodemirrorLanguageLoader>();

/**
 * Registers a language shortcut.
 *
 * @param name - identifier passed to an editor's `language` argument
 * @param loader - resolves to a module whose default export builds the extensions
 */
export function registerCodemirrorLanguage(
  name: string,
  loader: CodemirrorLanguageLoader
) {
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
 * @returns null when the name is unknown, so an editor can fall back to plain
 *   text
 */
export async function loadCodemirrorLanguage(
  name: string
): Promise<CodemirrorLanguageBuilder | null> {
  const loader = registered.get(name) || BUILT_IN[name];
  if (!loader) {
    warn(`Unknown CodeMirror language "${name}".`, {
      id: "discourse.codemirror-language-missing",
    });
    return null;
  }

  return (await waitForPromise(loader())).default;
}

export function codemirrorLanguageNames(): string[] {
  return [...new Set([...Object.keys(BUILT_IN), ...registered.keys()])].sort();
}

export function clearRegisteredCodemirrorLanguages() {
  registered.clear();
}
