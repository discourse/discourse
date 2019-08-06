import highlightText from "discourse/lib/highlight-text";

export default Ember.Component.extend({
  tagName: "span",

  _highlightOnInsert: function() {
    const term = this.highlight;
    highlightText($(this.element), term);
  }
    .observes("highlight")
    .on("didInsertElement")
});
