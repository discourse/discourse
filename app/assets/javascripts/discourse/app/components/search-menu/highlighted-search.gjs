import Component from "@glimmer/component";
import { action } from "@ember/object";
import didInsert from "@ember/render-modifiers/modifiers/did-insert";
import { service } from "@ember/service";
import htmlSafe from "discourse/helpers/html-safe";
import highlightSearch from "discourse/lib/highlight-search";

export default class HighlightedSearch extends Component {
  <template>
    <span {{didInsert this.highlight}}>
      {{htmlSafe @string}}
    </span>
  </template>
  @service search;

  @action
  highlight(element) {
    highlightSearch(element, this.search.activeGlobalSearchTerm);
  }
}
