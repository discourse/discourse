import Component from "@glimmer/component";
import { action } from "@ember/object";
import { service } from "@ember/service";
import highlightSearch from "discourse/lib/highlight-search";

export default class HighlightedSearch extends Component {
  @service search;

  @action
  highlight(element) {
    highlightSearch(element, this.search.activeGlobalSearchTerm);
  }
}
