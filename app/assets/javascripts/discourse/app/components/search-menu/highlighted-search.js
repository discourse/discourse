import Component from "@glimmer/component";
import { inject as service } from "@ember/service";
import highlightSearch from "discourse/lib/highlight-search";

export default class HighlightedSearch extends Component {
  @service search;

  constructor() {
    super(...arguments);
    const span = document.createElement("span");
    span.textContent = this.args.string;

    highlightSearch(span, this.search.activeGlobalSearchTerm);
  }
}
