import { SEARCH_PHRASE_REGEXP } from "discourse/lib/constants";
import highlightHTML from "discourse/lib/highlight-html";

export const CLASS_NAME = "search-highlight";

export default function(elem, term, opts = {}) {
  if (!_.isEmpty(term)) {
    // special case ignore "l" which is used for magic sorting
    let words = _.reject(
      term.match(new RegExp(`${SEARCH_PHRASE_REGEXP}|[^\\s]+`, "g")),
      t => t === "l"
    );

    words = words.map(w => w.replace(/^"(.*)"$/, "$1"));
    const highlightOpts = {};
    if (!opts.defaultClassName) highlightOpts.className = CLASS_NAME;
    highlightHTML(elem, words, highlightOpts);
  }
}
