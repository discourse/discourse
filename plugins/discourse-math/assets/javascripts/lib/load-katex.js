import {
  getKaTeX,
  loadCopyTex,
  loadKaTeX as loadKaTeXBundle,
  loadMhchem,
} from "discourse/plugins/discourse-math/lib/katex-bundle";

let basePromise;
let mhchemPromise;
let copyTexPromise;

export default async function loadKaTeX(options = {}) {
  if (!basePromise) {
    basePromise = loadKaTeXBundle();
  }
  await basePromise;

  if (options.enableMhchem && !mhchemPromise) {
    mhchemPromise = loadMhchem();
  }

  if (options.enableCopyTex && !copyTexPromise) {
    copyTexPromise = loadCopyTex();
  }

  await Promise.all([mhchemPromise, copyTexPromise].filter(Boolean));

  return getKaTeX() ?? window.katex;
}
