import { waitForPromise } from "@ember/test-waiters";

export default async function loadCodemirrorEditor() {
  return (
    await waitForPromise(
      import("discourse/static/codemirror/components/codemirror-editor")
    )
  ).default;
}
