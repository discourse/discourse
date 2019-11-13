import Component from "@ember/component";
import { default as discourseComputed } from "discourse-common/utils/decorators";

export default Component.extend({
  tagName: "span",

  @discourseComputed("text")
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
