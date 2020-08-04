import Component from "@ember/component";
import highlightSearch from "discourse/lib/highlight-search";
import { observes, on } from "discourse-common/utils/decorators";

export default Component.extend({
  tagName: "span",

  @on("didInsertElement")
  @observes("highlight")
  _highlightOnInsert: function() {
    const term = this.highlight;
    highlightSearch(this.element, term);
  }
});
