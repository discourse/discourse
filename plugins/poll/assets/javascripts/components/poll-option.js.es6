export default Em.Component.extend({
  tagName: "li",
  attributeBindings: ["data-poll-option-id", "data-poll-selected", "style"],

  "data-poll-option-id": Em.computed.alias("option.id"),

  "data-poll-selected": function() {
    return this.get("option.selected") ? "selected" : false;
  }.property("option.selected"),

  style: function() {
    var styles = [];
    if (this.get("color")) { styles.push("color:" + this.get("color")); }
    if (this.get("background")) { styles.push("background:" + this.get("background")); }
    return styles.length > 0 ? styles.join(";") : false;
  }.property("color", "background"),

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
