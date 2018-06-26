import { default as computed } from "ember-addons/ember-computed-decorators";

export default Ember.Component.extend({
  tagName: "button",
  classNames: ["btn-flat"],
  attributeBindings: ["disabled", "translatedTitle:title"],

  @computed("title")
  translatedTitle(title) {
    if (title) return I18n.t(title);
  },

  click() {
    return this.attrs.action();
  }
});
