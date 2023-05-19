import Component from "@glimmer/component";
import highlightSearch from "discourse/lib/highlight-search";

export default class HighlightedSearch extends Component {
  constructor() {
    super(...arguments);
    const span = document.createElement("span");
    span.textContent = this.args.string;
    this.content = span;

    highlightSearch(span, this.args.term);
  }
}
