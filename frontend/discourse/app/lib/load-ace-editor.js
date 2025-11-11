import { waitForPromise } from "@ember/test-waiters";

export default async function loadAce() {
  const promise = import("discourse/static/ace-editor-bundle");
  waitForPromise(promise);
  await promise;
  // TODO: fix this!!
  return window.ace;
}
