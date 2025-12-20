let outputPromise;
let mathmlPromise;

export function loadAsciiMath() {
  return import("mathjax/input/asciimath.js");
}

export function loadMathML() {
  return (mathmlPromise ??= import("mathjax/input/mml.js"));
}

export function loadOutput(output) {
  if (!outputPromise) {
    outputPromise =
      output === "svg"
        ? import("mathjax/tex-mml-svg.js")
        : import("mathjax/tex-mml-chtml.js");
  }

  return outputPromise;
}

export function loadA11yExplorer() {
  return import("mathjax/a11y/explorer.js");
}

export function getMathJax() {
  return window.MathJax;
}
