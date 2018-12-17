import { default as computed } from "ember-addons/ember-computed-decorators";

export default Ember.Component.extend({
  tagName: "span",

  @computed("text")
  translatedText(text) {
    if (text) return I18n.t(text);
  },

  click(event) {
    if (event.target.tagName.toUpperCase() === "A") {
      this.action(this.get("actionParam"));
    }

    return false;
  }
});
