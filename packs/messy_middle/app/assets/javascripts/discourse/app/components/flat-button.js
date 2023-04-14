import Component from "@ember/component";
import I18n from "I18n";
import discourseComputed from "discourse-common/utils/decorators";

export default Component.extend({
  tagName: "button",
  classNames: ["btn-flat"],
  attributeBindings: ["disabled", "translatedTitle:title"],

  @discourseComputed("title")
  translatedTitle(title) {
    if (title) {
      return I18n.t(title);
    }
  },

  keyDown(event) {
    if (event.key === "Enter") {
      this.action?.();
      return false;
    }
  },

  click() {
    this.action?.();
    return false;
  },
});
