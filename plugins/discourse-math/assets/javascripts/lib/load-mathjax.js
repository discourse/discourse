import {
  getMathJax,
  loadOutput,
} from "discourse/plugins/discourse-math/lib/mathjax-bundle";

// MathJax can only be initialized once per page load with a single output format.
// The output format is locked to whichever value is passed on the first call.
let outputPromise;

export default async function loadMathJax(options = {}) {
  const output = options.output === "svg" ? "svg" : "html";
  if (!outputPromise) {
    outputPromise = loadOutput(output);
  }
  await outputPromise;

  await window.MathJax.startup.promise;
  return getMathJax() ?? window.MathJax;
}
