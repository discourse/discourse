import { waitForPromise } from "@ember/test-waiters";

let importOverride = null;

/**
 * Loads the bare editor behind `<CodeEditor>`, for inline fields that want
 * none of its code-editing behaviour.
 *
 * @internal
 */
export default async function loadCodemirrorEditor() {
  return (
    await waitForPromise(
      importOverride?.() ??
        import("discourse/static/codemirror/components/codemirror-editor")
    )
  ).default;
}

/** @internal */
export function overrideCodemirrorImportForTesting(callback) {
  importOverride = callback;
}
