import { waitForPromise } from "@ember/test-waiters";

let basePromise;
let mhchemPromise;
let copyTexPromise;

export default async function loadKaTeX(options = {}) {
  const promise = (async () => {
    const module = await (basePromise ??= (async () => {
      const bundle = await import("discourse/static/katex-bundle");
      await bundle.loadKaTeX();
      return bundle;
    })());

    if (options.enableMhchem && !mhchemPromise) {
      mhchemPromise = module.loadMhchem();
    }

    if (options.enableCopyTex && !copyTexPromise) {
      copyTexPromise = module.loadCopyTex();
    }

    await Promise.all([mhchemPromise, copyTexPromise].filter(Boolean));

    return module.getKaTeX() ?? window.katex;
  })();

  waitForPromise(promise);
  return await promise;
}
