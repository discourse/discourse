import { waitForPromise } from "@ember/test-waiters";

/*
Plugins & themes are unable to async-import npm modules directly.
This wrapper provides them with a way to use @viz-js/viz, while keeping the `import()` in core's codebase.
*/
export default async function loadViz() {
  return await waitForPromise(import("@viz-js/viz"));
}
