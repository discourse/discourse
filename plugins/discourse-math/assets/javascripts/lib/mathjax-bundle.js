import { getURLWithCDN } from "discourse/lib/get-url";
import loadScript from "discourse/lib/load-script";
import { getMathJaxBasePath } from "discourse/plugins/discourse-math/lib/math-bundle-paths";

function getBasePath() {
  return getMathJaxBasePath();
}

// Output format is locked to the first call - MathJax can only be initialized once.
let outputPromise;

export function loadOutput(output) {
  if (!outputPromise) {
    const bundle = output === "svg" ? "tex-mml-svg.js" : "tex-mml-chtml.js";
    outputPromise = loadScript(getURLWithCDN(`${getBasePath()}/${bundle}`));
  }
  return outputPromise;
}

export function getMathJax() {
  return window.MathJax;
}
