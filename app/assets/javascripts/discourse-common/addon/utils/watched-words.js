export function createWatchedWordRegExp(word) {
  const caseFlag = word.case_sensitive ? "" : "i";
  return new RegExp(word.regexp, `${caseFlag}gu`);
}

export function buildWatchedWordMatcher(word, link = false) {
  return {
    partialRegexp: new RegExp(
      word.partial_regexp,
      word.case_sensitive ? "" : "i"
    ),
    regexp: createWatchedWordRegExp(word),
    replacement: word.replacement,
    link,
  };
}
