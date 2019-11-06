import Component from "@ember/component";
import { default as computed } from "ember-addons/ember-computed-decorators";

export default Component.extend({
  tagName: "span",

  @computed("text")
  translatedText(text) {
    if (text) return I18n.t(text);
  },

  click(event) {
    if (event.target.tagName.toUpperCase() === "A") {
      this.action(this.actionParam);
    }

    return false;
  }
});
