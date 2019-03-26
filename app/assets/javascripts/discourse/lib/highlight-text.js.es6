import { PHRASE_MATCH_REGEXP_PATTERN } from "discourse/lib/concerns/search-constants";

export default function($elem, term) {
  if (!_.isEmpty(term)) {
    // special case ignore "l" which is used for magic sorting
    let words = _.reject(
      term.match(new RegExp(`${PHRASE_MATCH_REGEXP_PATTERN}|[^\s]+`, "g")),
      t => t === "l"
    );

    words = words.map(w => w.replace(/^"(.*)"$/, "$1"));
    $elem.highlight(words, { className: "search-highlight", wordsOnly: true });
  }
}
