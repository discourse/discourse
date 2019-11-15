import Component from "@ember/component";
import highlightText from "discourse/lib/highlight-text";

export default Component.extend({
  tagName: "span",

  _highlightOnInsert: function() {
    const term = this.highlight;
    highlightText($(this.element), term);
  }
    .observes("highlight")
    .on("didInsertElement")
});
