import { waitForPromise } from "@ember/test-waiters";

/**
 * Loads the editor component behind `<CodeEditor>`.
 *
 * @internal Use `<CodeEditor>`; this component's arguments may change without
 * warning.
 */
export default async function loadCodemirrorEditor() {
  return (
    await waitForPromise(
      import("discourse/static/codemirror/components/codemirror-editor")
    )
  ).default;
}
