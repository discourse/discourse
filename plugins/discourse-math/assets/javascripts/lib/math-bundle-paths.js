import { helperContext } from "discourse/lib/helpers";

const FALLBACK_PUBLIC_BASE = "/plugins/discourse-math";

function getPublicBasePath() {
  const context = helperContext();
  return context?.site?.discourse_math_bundle_url || FALLBACK_PUBLIC_BASE;
}

export function getMathJaxBasePath() {
  return `${getPublicBasePath()}/mathjax`;
}

export function getKaTeXBasePath() {
  return `${getPublicBasePath()}/katex`;
}
