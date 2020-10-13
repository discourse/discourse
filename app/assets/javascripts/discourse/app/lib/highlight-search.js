import { SEARCH_PHRASE_REGEXP } from "discourse/lib/constants";
import highlightHTML from "discourse/lib/highlight-html";
import { isEmpty } from "@ember/utils";

export const CLASS_NAME = "search-highlight";

export default function (elem, term, opts = {}) {
  if (!isEmpty(term)) {
    // special case ignore "l" which is used for magic sorting
    let words = term
      .match(new RegExp(`${SEARCH_PHRASE_REGEXP}|[^\\s]+`, "g"))
      .filter((t) => t !== "l")
      .map((w) => w.replace(/^"(.*)"$/, "$1"));

    const highlightOpts = {};
    if (!opts.defaultClassName) {
      highlightOpts.className = CLASS_NAME;
    }
    highlightHTML(elem, words, highlightOpts);
  }
}
