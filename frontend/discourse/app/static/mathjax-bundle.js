import { getURLWithCDN } from "discourse/lib/get-url";
import loadScript from "discourse/lib/load-script";

const BASE_PATH = "/plugins/discourse-math/mathjax";

let outputPromise;
let asciimathPromise;
let a11yExplorerPromise;

export function loadOutput(output) {
  if (!outputPromise) {
    const bundle = output === "svg" ? "tex-mml-svg.js" : "tex-mml-chtml.js";
    outputPromise = loadScript(getURLWithCDN(`${BASE_PATH}/${bundle}`));
  }
  return outputPromise;
}

export function loadAsciiMath() {
  if (!asciimathPromise) {
    asciimathPromise = loadScript(
      getURLWithCDN(`${BASE_PATH}/input/asciimath.js`)
    );
  }
  return asciimathPromise;
}

export function loadA11yExplorer() {
  if (!a11yExplorerPromise) {
    a11yExplorerPromise = loadScript(
      getURLWithCDN(`${BASE_PATH}/a11y/explorer.js`)
    );
  }
  return a11yExplorerPromise;
}

export function getMathJax() {
  return window.MathJax;
}
