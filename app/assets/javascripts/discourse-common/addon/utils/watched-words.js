export function createWatchedWordRegExp(word) {
  const caseFlag = word.case_sensitive ? "" : "i";
  return new RegExp(word.regexp, `${caseFlag}gu`);
}
