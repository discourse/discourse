import { waitForPromise } from "@ember/test-waiters";

export default async function loadRichEditor() {
  return (
    await waitForPromise(
      import("discourse/static/prosemirror/components/prosemirror-editor")
    )
  ).default;
}
