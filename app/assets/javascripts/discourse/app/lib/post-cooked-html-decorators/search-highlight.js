import { unhighlightHTML } from "discourse/lib/highlight-html";
import highlightSearch from "discourse/lib/highlight-search";

export default function (element, context) {
  const { highlightTerm, cloakedState } = context;

  if (highlightTerm && highlightTerm.length > 2) {
    if (cloakedState.highlighted) {
      unhighlightHTML(element);
    }

    highlightSearch(element, highlightTerm, { defaultClassName: true });
    cloakedState.highlighted = true;
  } else if (cloakedState.highlighted) {
    unhighlightHTML(element);
    cloakedState.highlighted = false;
  }
}
