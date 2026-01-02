import { getURLWithCDN } from "discourse/lib/get-url";
import loadScript from "discourse/lib/load-script";

const BASE_PATH = "/plugins/discourse-math/katex";

let katexPromise;
let cssPromise;
let mhchemPromise;
let copyTexPromise;

export async function loadKaTeX() {
  if (!cssPromise) {
    cssPromise = loadScript(getURLWithCDN(`${BASE_PATH}/katex.min.css`), {
      css: true,
    });
  }
  await cssPromise;

  if (!katexPromise) {
    katexPromise = loadScript(getURLWithCDN(`${BASE_PATH}/katex.min.js`));
  }
  await katexPromise;

  return window.katex;
}

export function loadMhchem() {
  if (!mhchemPromise) {
    mhchemPromise = loadScript(
      getURLWithCDN(`${BASE_PATH}/contrib/mhchem.min.js`)
    );
  }
  return mhchemPromise;
}

export function loadCopyTex() {
  if (!copyTexPromise) {
    copyTexPromise = loadScript(
      getURLWithCDN(`${BASE_PATH}/contrib/copy-tex.min.js`)
    );
  }
  return copyTexPromise;
}

export function getKaTeX() {
  return window.katex;
}
