import { unhighlightHTML } from "discourse/lib/highlight-html";
import highlightSearch from "discourse/lib/highlight-search";

export default function (element, context) {
  const { highlightTerm, decoratorState } = context;

  if (highlightTerm && highlightTerm.length > 2) {
    if (decoratorState.highlighted) {
      unhighlightHTML(element);
    }

    highlightSearch(element, highlightTerm, { defaultClassName: true });
    decoratorState.highlighted = true;
  } else if (decoratorState.highlighted) {
    unhighlightHTML(element);
    decoratorState.highlighted = false;
  }
}
