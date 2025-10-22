import highlightSearch from "discourse/lib/highlight-search";

export default function (element, context) {
  const { highlightTerm } = context;

  if (highlightTerm && highlightTerm.length > 2) {
    highlightSearch(element, highlightTerm, { defaultClassName: true });
  }
}
