export function censorFn(regexpString, replacementLetter) {
  if (regexpString) {
    let censorRegexp = new RegExp(regexpString, "ig");
    replacementLetter = replacementLetter || "&#9632;";

    return function(text) {
      text = text.replace(censorRegexp, (fullMatch, ...groupMatches) => {
        const stringMatch = groupMatches.find(g => typeof g === "string");
        return fullMatch.replace(
          stringMatch,
          new Array(stringMatch.length + 1).join(replacementLetter)
        );
      });

      return text;
    };
  }

  return function(t) {
    return t;
  };
}

export function censor(text, censoredRegexp, replacementLetter) {
  return censorFn(censoredRegexp, replacementLetter)(text);
}
