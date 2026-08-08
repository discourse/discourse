import Modifier from "ember-modifier";

function tokenize(value) {
  return value?.split(/\s+/).filter(Boolean) ?? [];
}

export default function mergeDataAttributeTokens(attributeName) {
  return class MergeDataAttributeTokens extends Modifier {
    #previousExtraTokens = [];

    modify(element, positional) {
      const previousTokenSet = new Set(this.#previousExtraTokens);
      const currentTokens = tokenize(element.getAttribute(attributeName));
      const consumerTokens = currentTokens.filter(
        (token) => !previousTokenSet.has(token)
      );
      const extraTokens = tokenize(positional.flat().filter(Boolean).join(" "));
      const mergedTokens = [...new Set([...consumerTokens, ...extraTokens])];

      if (mergedTokens.length) {
        element.setAttribute(attributeName, mergedTokens.join(" "));
      } else {
        element.removeAttribute(attributeName);
      }

      this.#previousExtraTokens = extraTokens;
    }
  };
}
