// a "#" or "@" being typed is asking for core's suggestions, not a search
const SUGGESTION_IN_PROGRESS = /(?:^|\s)[#@]\S*$/;

// quoted phrases and search operators are someone after precise results
const SEARCH_SYNTAX =
  /"[^"]+"|(?:^|\s)-?(?:in|status|order|before|after|with|category|categories|tags?|user|group|badge|topic|min_\w+|max_\w+):\S|(?:^|\s)[#@]\S+/i;

const QUESTION_MARK = /[?？]\s*$/;

// this many words is natural language rather than keywords
const QUESTION_LENGTH = 5;

// as few keyword matches as this and an answer is worth having after all
const FEW_KEYWORD_MATCHES = 3;

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
 * @typedef {Object} PauseDecision
 * @property {boolean} answer whether to ask for an AI answer straight away
 * @property {string} reason why it answers, or why it does not
 * @property {(results: Object) => boolean} [answerAfter] when not answering
 *   straight away, whether to ask once the keyword results are in
 * @property {string} [answerAfterReason] why, when it then does
 */

/**
 * What a pause in typing should do with the query. Pressing enter always
 * answers; a pause answers when the query reads as a question, and leaves the
 * AI out when it reads as a lookup.
 *
 * @param {string} query
 * @param {Object} [instantResults] the menu's results as the reader typed
 * @param {Object} [context]
 * @param {string} [context.siteLocale] the language the site is searched in
 * @param {boolean} [context.searchedAgain] whether the reader is still
 *   searching after an earlier search on this page
 * @param {string} [context.scope] the scope the search runs in
 * @returns {PauseDecision}
 */
export function pauseDecision(
  query,
  instantResults,
  { siteLocale, searchedAgain, scope } = {}
) {
  if (usesSearchSyntax(query)) {
    return { answer: false, reason: "syntax" };
  }

  // within a topic the reader is after a passage of it, which a keyword match
  // finds; the answer is for when nothing in the topic matches
  if (scope?.startsWith("topic:")) {
    return {
      answer: false,
      reason: "topic_match",
      answerAfter: (results) => !results?.posts?.length,
      answerAfterReason: "no_topic_match",
    };
  }

  // keyword search does poorly outside the site's language, which the answer
  // bridges by searching in it
  if (inForeignScript(query, siteLocale)) {
    return { answer: true, reason: "language" };
  }

  // a second search here means the first one's results did not help
  if (searchedAgain) {
    return { answer: true, reason: "searched_again" };
  }

  if (readsAsQuestion(query)) {
    return { answer: true, reason: "question" };
  }

  // a person or place is usually where the reader is going, unless the
  // keywords then find little else
  if (matchesPlaces(instantResults)) {
    return {
      answer: false,
      reason: "places",
      answerAfter: (results) =>
        (results?.posts?.length ?? 0) <= FEW_KEYWORD_MATCHES,
      answerAfterReason: "few_matches",
    };
  }

  return {
    answer: false,
    reason: "title_match",
    answerAfter: (results) => !topResultIsTitled(query, results),
    answerAfterReason: "no_title_match",
  };
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

export function suggestionInProgress(query) {
  return SUGGESTION_IN_PROGRESS.test(query ?? "");
}

export function usesSearchSyntax(query) {
  return SEARCH_SYNTAX.test(query ?? "");
}

export function readsAsQuestion(query) {
  return QUESTION_MARK.test(query ?? "") || wordCount(query) >= QUESTION_LENGTH;
}

/** Whether the results include any people, groups, categories or tags. */
export function matchesPlaces(results) {
  return ["users", "groups", "categories", "tags"].some(
    (kind) => results?.[kind]?.length > 0
  );
}

/**
 * Whether the best keyword match is titled with (nearly) the query, which is
 * someone heading for that topic.
 */
export function topResultIsTitled(query, results) {
  const title = normalize(results?.posts?.[0]?.topic?.title);
  const wanted = normalize(query);
  if (!title || !wanted) {
    return false;
  }

  if (title === wanted) {
    return true;
  }

  const [shorter, longer] =
    title.length < wanted.length ? [title, wanted] : [wanted, title];
  return longer.includes(shorter) && shorter.length / longer.length >= 0.8;
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

function normalize(value) {
  return (value ?? "")
    .toString()
    .toLowerCase()
    .replace(/[^\p{L}\p{N}\s]/gu, "")
    .replace(/\s+/g, " ")
    .trim();
}
