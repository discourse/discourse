import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { inject as service } from "@ember/service";
import highlightSearch from "discourse/lib/highlight-search";

export default class HighlightedSearch extends Component {
  @service search;
  @tracked highlighted;

  constructor() {
    super(...arguments);
    const span = document.createElement("span");
    span.textContent = this.args.string;

    highlightSearch(span, this.search.activeGlobalSearchTerm);
    this.highlighted = span.innerHTML;
  }
}
