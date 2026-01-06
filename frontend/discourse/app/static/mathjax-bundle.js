import { getURLWithCDN } from "discourse/lib/get-url";
import loadScript from "discourse/lib/load-script";
import { getMathJaxBasePath } from "discourse/plugins/discourse-math/lib/math-bundle-paths";

function getBasePath() {
  return getMathJaxBasePath();
}

let outputPromise;
let asciimathPromise;
let a11yExplorerPromise;

export function loadOutput(output) {
  if (!outputPromise) {
    const bundle = output === "svg" ? "tex-mml-svg.js" : "tex-mml-chtml.js";
    outputPromise = loadScript(getURLWithCDN(`${getBasePath()}/${bundle}`));
  }
  return outputPromise;
}

export function loadAsciiMath() {
  if (!asciimathPromise) {
    asciimathPromise = loadScript(
      getURLWithCDN(`${getBasePath()}/input/asciimath.js`)
    );
  }
  return asciimathPromise;
}

export function loadA11yExplorer() {
  if (!a11yExplorerPromise) {
    a11yExplorerPromise = loadScript(
      getURLWithCDN(`${getBasePath()}/a11y/explorer.js`)
    );
  }
  return a11yExplorerPromise;
}

export function getMathJax() {
  return window.MathJax;
}
