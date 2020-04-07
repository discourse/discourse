import Component from "@ember/component";
import highlightSearch from "discourse/lib/highlight-search";

export default Component.extend({
  tagName: "span",

  _highlightOnInsert: function() {
    const term = this.highlight;
    highlightSearch(this.element, term);
  }
    .observes("highlight")
    .on("didInsertElement")
});
