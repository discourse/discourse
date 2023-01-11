import {
  createWatchedWordRegExp,
  toWatchedWord,
} from "discourse-common/utils/watched-words";

export function censorFn(regexpList, replacementLetter) {
  if (regexpList?.length) {
    replacementLetter = replacementLetter || "&#9632;";
    let censorRegexps = regexpList.map((regexp) => {
      return createWatchedWordRegExp(toWatchedWord(regexp));
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
