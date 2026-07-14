import { waitForPromise } from "@ember/test-waiters";

export default async function loadRete() {
  const promise = import("discourse/static/rete-bundle");
  waitForPromise(promise);
  return await promise;
}
