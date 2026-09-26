import Component from "@glimmer/component";
import { action } from "@ember/object";
import didInsert from "@ember/render-modifiers/modifiers/did-insert";
import { service } from "discourse/lib/service";
import { trustHTML } from "@ember/template";
import highlightSearch from "discourse/lib/highlight-search";
import SearchService from "discourse/services/search";

export default class HighlightedSearch extends Component {
  @service(() => SearchService) search;

  @action
  highlight(element) {
    highlightSearch(element, this.search.activeGlobalSearchTerm);
  }

  <template>
    <span {{didInsert this.highlight}}>
      {{trustHTML @string}}
    </span>
  </template>
}
