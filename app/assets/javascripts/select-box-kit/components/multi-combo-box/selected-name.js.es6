import computed from "ember-addons/ember-computed-decorators";

export default Ember.Component.extend({
  attributeBindings: [
    "tabindex",
    "content.name:data-name",
    "content.value:data-value",
    "guid:data-guid"
  ],
  classNames: "selected-name",
  classNameBindings: ["isHighlighted", "isLocked"],
  layoutName: "select-box-kit/templates/components/multi-combo-box/selected-name",
  tagName: "li",
  tabindex: -1,

  @computed("content")
  guid(content) { return Ember.guidFor(content); },

  isLocked: Ember.computed("content.locked", function() {
    return this.getWithDefault("content.locked", false);
  }),

  click() {
    if (this.get("isLocked") === true) { return false; }
    this.toggleProperty("isHighlighted");
    return false;
  }
});
