import { on, observes } from 'ember-addons/ember-computed-decorators';

export default Ember.Component.extend({
  classNames: "select-box-row",

  tagName: "li",

  classNameBindings: ["isHighlighted"],

  attributeBindings: ["text:title"],

  lastHoveredId: null,

  @on("init")
  @observes("content", "lastHoveredId", "selectedId", "selectBoxRowTemplate")
  _updateTemplate: function() {
    this.set("isHighlighted", this._isHighlighted());
    this.set("text", this.get("content.text"));
    this.set("template", this.get("selectBoxRowTemplate")(this));
  },

  mouseEnter() {
    this.sendAction("onHover", this.get("content.id"));
  },

  click() {
    this.sendAction("onSelect", this.get("content.id"));
  },

  didReceiveAttrs() {
    this._super();

    this.set("isHighlighted", this._isHighlighted());
    this.set("text", this.get("content.text"));
  },

  _isHighlighted() {
    if(_.isUndefined(this.get("lastHoveredId"))) {
      return this.get("content.id") === this.get("selectedId");
    } else {
      return this.get("content.id") === this.get("lastHoveredId");
    }
  },
});
