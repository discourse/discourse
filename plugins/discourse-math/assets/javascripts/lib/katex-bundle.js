import { getURLWithCDN } from "discourse/lib/get-url";
import loadScript from "discourse/lib/load-script";
import { getKaTeXBasePath } from "discourse/plugins/discourse-math/lib/math-bundle-paths";

function getBasePath() {
  return getKaTeXBasePath();
}

let katexPromise;
let cssPromise;
let mhchemPromise;
let copyTexPromise;

export async function loadKaTeX() {
  if (!cssPromise) {
    cssPromise = loadScript(getURLWithCDN(`${getBasePath()}/katex.min.css`), {
      css: true,
    });
  }
  await cssPromise;

  if (!katexPromise) {
    katexPromise = loadScript(getURLWithCDN(`${getBasePath()}/katex.min.js`));
  }
  await katexPromise;

  return window.katex;
}

export function loadMhchem() {
  if (!mhchemPromise) {
    mhchemPromise = loadScript(
      getURLWithCDN(`${getBasePath()}/contrib/mhchem.min.js`)
    );
  }
  return mhchemPromise;
}

export function loadCopyTex() {
  if (!copyTexPromise) {
    copyTexPromise = loadScript(
      getURLWithCDN(`${getBasePath()}/contrib/copy-tex.min.js`)
    );
  }
  return copyTexPromise;
}

export function getKaTeX() {
  return window.katex;
}
