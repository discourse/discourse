import { waitForPromise } from "@ember/test-waiters";

export default async function loadMiniMasonry() {
  const promise = import(/* dynamicChunkName: "minimasonry" */ "minimasonry");
  waitForPromise(promise);
  return (await promise).default;
}
