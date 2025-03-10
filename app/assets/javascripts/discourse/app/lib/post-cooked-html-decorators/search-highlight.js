import { unhighlightHTML } from "discourse/lib/highlight-html";
import highlightSearch from "discourse/lib/highlight-search";

export default function (element, context) {
  const { data, state } = context;
  const highlight = data.highlightTerm;

  if (highlight && highlight.length > 2) {
    if (state.highlighted) {
      unhighlightHTML(element);
    }

    highlightSearch(element, highlight, { defaultClassName: true });
    state.highlighted = true;
  } else if (state.highlighted) {
    unhighlightHTML(element);
    state.highlighted = false;
  }
}
