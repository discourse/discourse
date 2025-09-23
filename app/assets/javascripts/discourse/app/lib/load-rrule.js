import { waitForPromise } from "@ember/test-waiters";

export default async function loadRRule() {
  const promise = import("discourse/static/rrule-bundle");
  waitForPromise(promise);
  return await promise;
}
