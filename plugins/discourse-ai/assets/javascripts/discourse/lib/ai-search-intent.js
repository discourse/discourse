// quoted phrases and search operators are someone after precise results
const SEARCH_SYNTAX =
  /"[^"]+"|(?:^|\s)-?(?:in|status|order|before|after|with|category|categories|tags?|user|group|badge|topic|min_\w+|max_\w+):\S|(?:^|\s)[#@]\S+/i;

const QUESTION_MARK = /[?？]\s*$/;

// this many words is natural language rather than keywords
const QUESTION_LENGTH = 5;

// the writing systems each site language is searched in; anything else is
// left out of the search index's stemming and matches poorly
const LOCALE_SCRIPTS = {
  ar: ["Arabic"],
  be: ["Cyrillic"],
  bg: ["Cyrillic"],
  el: ["Greek"],
  fa: ["Arabic"],
  he: ["Hebrew"],
  hi: ["Devanagari"],
  ja: ["Han", "Hiragana", "Katakana"],
  kk: ["Cyrillic"],
  ko: ["Hangul", "Han"],
  mk: ["Cyrillic"],
  ru: ["Cyrillic"],
  sr: ["Cyrillic", "Latin"],
  th: ["Thai"],
  uk: ["Cyrillic"],
  ur: ["Arabic"],
  zh: ["Han"],
};
const DETECTED_SCRIPTS = [
  "Latin",
  "Cyrillic",
  "Greek",
  "Arabic",
  "Hebrew",
  "Devanagari",
  "Han",
  "Hiragana",
  "Katakana",
  "Hangul",
  "Thai",
].map((name) => [name, new RegExp(`\\p{Script=${name}}`, "u")]);
const FOREIGN_SHARE = 0.6;

/**
 * @typedef {"ask"|"topics"|"context"} SearchTab
 */

/**
 * Which tab a search should open on, guessed from how the query reads and
 * what the keyword searches found. Every tab is fetched, so this only decides
 * what the reader sees first.
 *
 * @param {string} query
 * @param {Object} found
 * @param {Object} [found.topics] the site-wide keyword results
 * @param {Object} [found.context] the keyword results within the context
 * @param {string} [found.scope] the context's scope key, when there is one
 * @param {string} [found.siteLocale] the language the site is searched in
 * @param {boolean} [found.searchedAgain] whether an earlier search on this
 *   page seems not to have helped
 * @returns {{tab: SearchTab, reason: string}}
 */
export function chooseTab(
  query,
  { topics, context, scope, siteLocale, searchedAgain } = {}
) {
  const topicCount = topics?.posts?.length ?? 0;
  const contextCount = scope ? (context?.posts?.length ?? 0) : 0;

  if (usesSearchSyntax(query)) {
    return {
      tab: contextCount > 0 ? "context" : "topics",
      reason: "syntax",
    };
  }

  // within a topic the reader is after a passage of it
  if (scope?.startsWith("topic:") && contextCount > 0) {
    return { tab: "context", reason: "topic_match" };
  }

  // keyword search does poorly outside the site's language
  if (inForeignScript(query, siteLocale)) {
    return { tab: "ask", reason: "language" };
  }

  // a second search here means the first one's results did not help
  if (searchedAgain) {
    return { tab: "ask", reason: "searched_again" };
  }

  if (readsAsQuestion(query)) {
    return { tab: "ask", reason: "question" };
  }

  if (contextCount > 0) {
    return { tab: "context", reason: "context_match" };
  }

  if (topicCount > 0) {
    return { tab: "topics", reason: "topic_results" };
  }

  return { tab: "ask", reason: "no_keyword_matches" };
}

/**
 * Whether most of the query's letters are in a writing system the site's
 * language does not use.
 */
export function inForeignScript(query, siteLocale) {
  const expected = LOCALE_SCRIPTS[(siteLocale ?? "").split(/[_-]/)[0]] ?? [
    "Latin",
  ];
  const letters = [...(query ?? "")].filter((char) => /\p{L}/u.test(char));
  if (letters.length === 0) {
    return false;
  }

  // Latin letters are never counted: product names, code and borrowed terms
  // are written in them on sites in any language
  const foreign = letters.filter((char) => {
    const script = DETECTED_SCRIPTS.find(([, pattern]) => pattern.test(char));
    return script && script[0] !== "Latin" && !expected.includes(script[0]);
  });
  return foreign.length / letters.length >= FOREIGN_SHARE;
}

export function usesSearchSyntax(query) {
  return SEARCH_SYNTAX.test(query ?? "");
}

export function readsAsQuestion(query) {
  return QUESTION_MARK.test(query ?? "") || wordCount(query) >= QUESTION_LENGTH;
}

/**
 * Words rather than spaces, so a question in a language written without
 * spaces between words still counts as several.
 */
export function wordCount(query) {
  const text = query?.trim() ?? "";
  if (!text) {
    return 0;
  }

  if (typeof Intl?.Segmenter === "function") {
    const segments = new Intl.Segmenter(undefined, { granularity: "word" });
    return [...segments.segment(text)].filter((s) => s.isWordLike).length;
  }

  return text.split(/\s+/).length;
}
