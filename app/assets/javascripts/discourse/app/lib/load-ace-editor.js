import { waitForPromise } from "@ember/test-waiters";
import { isTesting } from "discourse-common/config/environment";

export default async function loadAce() {
  const promise = import("discourse/static/ace-editor-bundle");
  if (isTesting()) {
    waitForPromise(promise);
  }
  return await promise;
}
