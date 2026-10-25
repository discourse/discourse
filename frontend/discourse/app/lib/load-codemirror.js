import { waitForPromise } from "@ember/test-waiters";

/**
 * Loads the bare editor behind `<CodeEditor>`, for inline fields that want
 * none of its code-editing behaviour.
 *
 * @internal
 */
export default async function loadCodemirrorEditor() {
  return (
    await waitForPromise(
      import("discourse/static/codemirror/components/codemirror-editor")
    )
  ).default;
}
