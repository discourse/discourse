import { getURLWithCDN } from "discourse/lib/get-url";
import loadScript from "discourse/lib/load-script";

let katexPromise;
let cssPromise;

export async function loadKaTeX() {
  // Load CSS first (required for proper rendering)
  if (!cssPromise) {
    cssPromise = loadScript(getURLWithCDN("/assets/katex/katex.min.css"), {
      css: true,
    });
  }
  await cssPromise;

  // Load KaTeX JavaScript via dynamic import
  if (!katexPromise) {
    katexPromise = import("katex");
  }
  const katexModule = await katexPromise;
  window.katex = katexModule.default;
  return katexModule.default;
}

export function loadMhchem() {
  return import("katex/contrib/mhchem");
}

export function loadCopyTex() {
  return import("katex/contrib/copy-tex");
}

export function getKaTeX() {
  return window.katex;
}
