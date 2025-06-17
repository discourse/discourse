import { unhighlightHTML } from "discourse/lib/highlight-html";
import highlightSearch from "discourse/lib/highlight-search";

export default function (element, context) {
  const { data, cloakedState } = context;
  const highlight = data.highlightTerm;

  if (highlight && highlight.length > 2) {
    if (cloakedState.highlighted) {
      unhighlightHTML(element);
    }

    highlightSearch(element, highlight, { defaultClassName: true });
    cloakedState.highlighted = true;
  } else if (cloakedState.highlighted) {
    unhighlightHTML(element);
    cloakedState.highlighted = false;
  }
}
