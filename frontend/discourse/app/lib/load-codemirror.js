import { waitForPromise } from "@ember/test-waiters";

let importOverride = null;

/**
 * Loads the bare editor behind `<CodeEditor>`, for inline fields that want
 * none of its code-editing behaviour.
 *
 * @param {object} [options]
 * @param {boolean} [options.expressionUtils] also loads the expression helpers
 *   that extension builders then receive as `utils`
 * @internal
 */
export default async function loadCodemirrorEditor({
  expressionUtils = false,
} = {}) {
  const module = await waitForPromise(
    importOverride?.() ??
      import("discourse/static/codemirror/components/codemirror-editor")
  );

  if (expressionUtils) {
    await waitForPromise(module.loadExpressionUtils());
  }

  return module.default;
}

/** @internal */
export function overrideCodemirrorImportForTesting(callback) {
  importOverride = callback;
}
