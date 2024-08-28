import Component from "@ember/component";
import { tagName } from "@ember-decorators/component";
import { observes, on } from "@ember-decorators/object";
import highlightSearch from "discourse/lib/highlight-search";

@tagName("span")
export default class HighlightSearch extends Component {
  @on("didInsertElement")
  @observes("highlight")
  _highlightOnInsert() {
    const term = this.highlight;
    highlightSearch(this.element, term);
  }
}
