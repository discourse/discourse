export default Em.Component.extend({
  tagName: "li",
  attributeBindings: ["data-poll-option-id", "data-poll-selected"],

  "data-poll-option-id": Em.computed.alias("option.id"),

  "data-poll-selected": function() {
    return this.get("option.selected") ? "selected" : false;
  }.property("option.selected"),

  render(buffer) {
    buffer.push(this.get("option.html"));
  },

  click(e) {
    // ensure we're not clicking on a link
    if ($(e.target).closest("a").length === 0) {
      this.sendAction("toggle", this.get("option"));
    }
  }
});
