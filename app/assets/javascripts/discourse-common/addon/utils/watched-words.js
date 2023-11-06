export function createWatchedWordRegExp(word) {
  const caseFlag = word.case_sensitive ? "" : "i";
  return new RegExp(word.full_regexp || word.regexp, `${caseFlag}gu`);
}
