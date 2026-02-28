import { modifier } from "ember-modifier";

const PREVIOUS_EXTRA_TOKENS = new WeakMap();

function tokenize(value) {
  return value?.split(/\s+/).filter(Boolean) || [];
}

export default modifier((element, positional) => {
  const previousExtraTokens = PREVIOUS_EXTRA_TOKENS.get(element) || [];
  const previousExtraTokenSet = new Set(previousExtraTokens);

  const currentTokens = tokenize(element.getAttribute("data-d-sheet"));
  const baseTokens = currentTokens.filter(
    (token) => !previousExtraTokenSet.has(token)
  );

  const extraTokens = tokenize(positional.flat().filter(Boolean).join(" "));
  const mergedTokens = [...new Set([...baseTokens, ...extraTokens])];

  if (mergedTokens.length) {
    element.setAttribute("data-d-sheet", mergedTokens.join(" "));
  } else {
    element.removeAttribute("data-d-sheet");
  }

  PREVIOUS_EXTRA_TOKENS.set(element, extraTokens);
});
