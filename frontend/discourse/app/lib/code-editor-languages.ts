import { warn } from "@ember/debug";
import { waitForPromise } from "@ember/test-waiters";
import type { Extension } from "@codemirror/state";

/**
 * Named shortcuts for a code editor's language support.
 *
 * A shortcut resolves to editor extensions, so it can carry anything a
 * language needs (highlighting, indentation, its own completions) while
 * callers stay free to append more through the editor's `extensions` argument.
 *
 * The built-in set loads on demand; plugins add their own with
 * {@link registerCodeEditorLanguage}.
 *
 * EXPERIMENTAL: the parameters builders receive expose the underlying editor
 * library, and may change without warning.
 */

/**
 * What every extension builder receives. Plugins cannot import the editor's
 * modules themselves, so they arrive here instead.
 *
 * @experimental Exposes the underlying editor library; may change without
 * warning.
 */
export interface CodeEditorParams {
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
  /**
   * Helpers for `{{ }}` expression editors.
   *
   * @internal Not part of the contract, experimental or otherwise.
   */
  utils: (typeof import("discourse/static/codemirror/expression-utils"))["expressionUtils"];
}

/**
 * Builds the extensions an editor's `extensions` argument adds on top of the
 * language.
 *
 * @experimental
 */
export type CodeEditorExtensionBuilder = (
  params: CodeEditorParams
) => readonly Extension[];

/**
 * Builds a language's extensions. `options` is whatever the editor was given
 * as `languageOptions`, so a language decides its own configuration shape.
 *
 * @experimental
 */
export type CodeEditorLanguageBuilder<Options extends object = object> = (
  params: CodeEditorParams,
  options?: Options
) => Extension;

/**
 * Resolves to a module whose default export builds the language.
 *
 * @experimental
 */
export type CodeEditorLanguageLoader = () => Promise<{
  default: CodeEditorLanguageBuilder;
}>;

const BUILT_IN: Record<string, CodeEditorLanguageLoader> = {
  css: () => import("discourse/static/codemirror/languages/css"),
  html: () => import("discourse/static/codemirror/languages/html"),
  javascript: () => import("discourse/static/codemirror/languages/javascript"),
  json: () => import("discourse/static/codemirror/languages/json"),
  scss: () => import("discourse/static/codemirror/languages/scss"),
  sql: () => import("discourse/static/codemirror/languages/sql"),
  yaml: () => import("discourse/static/codemirror/languages/yaml"),
};

const registered = new Map<string, CodeEditorLanguageLoader>();

/**
 * Registers a language shortcut.
 *
 * @experimental The builder a language provides receives the underlying
 * editor library, which may change without warning.
 *
 * @param name - identifier passed to an editor's `language` argument
 * @param loader - resolves to a module whose default export builds the extensions
 */
export function registerCodeEditorLanguage(
  name: string,
  loader: CodeEditorLanguageLoader
) {
  // Taking a name that already resolves is allowed — a plugin may have a
  // better grammar for it — but it is worth saying so, since two plugins
  // claiming one name would otherwise silently come down to load order.
  if (registered.has(name) || BUILT_IN[name]) {
    warn(`The code editor language "${name}" was already registered.`, {
      id: "discourse.code-editor-language-override",
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
export async function loadCodeEditorLanguage(
  name: string
): Promise<CodeEditorLanguageBuilder | null> {
  const loader = registered.get(name) || BUILT_IN[name];
  if (!loader) {
    warn(`Unknown code editor language "${name}".`, {
      id: "discourse.code-editor-language-missing",
    });
    return null;
  }

  return (await waitForPromise(loader())).default;
}

export function codeEditorLanguageNames(): string[] {
  return [...new Set([...Object.keys(BUILT_IN), ...registered.keys()])].sort();
}

export function clearRegisteredCodeEditorLanguages() {
  registered.clear();
}
