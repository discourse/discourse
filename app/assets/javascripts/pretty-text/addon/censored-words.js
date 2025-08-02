export function censorFn(regexpList, replacementLetter = "&#9632;") {
  if (regexpList?.length) {
    const censorRegexps = regexpList.map((entry) => {
      const [regexp, options] = Object.entries(entry)[0];
      return new RegExp(regexp, options.case_sensitive ? "gu" : "gui");
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
