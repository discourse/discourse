import { waitForPromise } from "@ember/test-waiters";

let basePromise;
let asciimathPromise;
let a11yPromise;

export default async function loadMathJax(options = {}) {
  const output = options.output === "svg" ? "svg" : "html";
  const promise = (async () => {
    const module = await (basePromise ??= (async () => {
      const bundle = await import("discourse/static/mathjax-bundle");
      await bundle.loadOutput?.(output);
      return bundle;
    })());

    if (options.enableAsciimath && !asciimathPromise) {
      asciimathPromise = module.loadAsciiMath?.();
    }

    if (options.enableAccessibility && !a11yPromise) {
      // Tell MathJax's loader these modules are being loaded via webpack
      // to prevent it from trying to fetch them separately
      window.MathJax?.loader?.preLoad?.("a11y/sre", "a11y/explorer");
      a11yPromise = module.loadA11yExplorer?.();
    }

    await Promise.all([asciimathPromise, a11yPromise].filter(Boolean));
    await window.MathJax?.startup?.promise;

    return module.getMathJax?.() ?? window.MathJax;
  })();

  waitForPromise(promise);
  return await promise;
}
