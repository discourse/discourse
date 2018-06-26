import highlightText from "discourse/lib/highlight-text";

export default Ember.Component.extend({
  tagName: "span",

  _highlightOnInsert: function() {
    const term = this.get("highlight");
    highlightText(this.$(), term);
  }
    .observes("highlight")
    .on("didInsertElement")
});
