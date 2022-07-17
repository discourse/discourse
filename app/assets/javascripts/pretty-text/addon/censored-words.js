export function censorFn(regexpList, replacementLetter) {
  if (regexpList.length) {
    replacementLetter = replacementLetter || "&#9632;";
    let censorRegexps = regexpList.map((regexp) => {
      let [[regexpString, options]] = Object.entries(regexp);
      let caseFlag = options.case_sensitive ? "" : "i";
      return new RegExp(regexpString, `${caseFlag}g`);
    });

    return function (text) {
      censorRegexps.forEach((censorRegexp) => {
        text = text.replace(censorRegexp, (fullMatch, ...groupMatches) => {
          const stringMatch = groupMatches.find((g) => typeof g === "string");
          return fullMatch.replace(
            stringMatch,
            new Array(stringMatch.length + 1).join(replacementLetter)
          );
        });
      });

      return text;
    };
  }

  return function (t) {
    return t;
  };
}

export function censor(text, censoredRegexp, replacementLetter) {
  return censorFn(censoredRegexp, replacementLetter)(text);
}
