import { observes, on } from "discourse-common/utils/decorators";
import Component from "@ember/component";
import highlightSearch from "discourse/lib/highlight-search";

export default Component.extend({
  tagName: "span",

  @on("didInsertElement")
  @observes("highlight")
  _highlightOnInsert() {
    const term = this.highlight;
    highlightSearch(this.element, term);
  },
});
