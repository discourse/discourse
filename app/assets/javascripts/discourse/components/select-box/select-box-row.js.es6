export default Ember.Component.extend({
  classNames: "select-box-row",

  tagName: "li",

  classNameBindings: ["isHighlighted"],

  attributeBindings: ["text:title"],

  lastHoveredId: null,

  mouseEnter() {
    this.sendAction("onHover", this.get("data.id"));
  },

  click() {
    this.sendAction("onSelect", this.get("data.id"));
  },

  didReceiveAttrs() {
    this._super();

    this.set("isHighlighted", this._isHighlighted());
    this.set("text", this.get("data.text"));
  },

  _isHighlighted() {
    if(_.isUndefined(this.get("lastHoveredId"))) {
      return this.get("data.id") === this.get("selectedId");
    } else {
      return this.get("data.id") === this.get("lastHoveredId");
    }
  },
});
