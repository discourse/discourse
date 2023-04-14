export function createWatchedWordRegExp(word) {
  const caseFlag = word.case_sensitive ? "" : "i";
  return new RegExp(word.regexp, `${caseFlag}g`);
}

export function toWatchedWord(regexp) {
  const [[regexpString, options]] = Object.entries(regexp);
  return { regexp: regexpString, ...options };
}
