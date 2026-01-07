import { waitForPromise } from "@ember/test-waiters";

// MathJax can only be initialized once per page load with a single output format.
// The output format is locked to whichever value is passed on the first call.
let basePromise;

export default async function loadMathJax(options = {}) {
  const output = options.output === "svg" ? "svg" : "html";
  const promise = (async () => {
    const module = await (basePromise ??= (async () => {
      const bundle = await import("discourse/static/mathjax-bundle");
      await bundle.loadOutput(output);
      return bundle;
    })());

    await window.MathJax.startup.promise;
    return module.getMathJax() ?? window.MathJax;
  })();

  waitForPromise(promise);
  return await promise;
}
