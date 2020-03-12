import Component from "@ember/component";
import discourseComputed from "discourse-common/utils/decorators";

export default Component.extend({
  tagName: "button",
  classNames: ["btn-flat"],
  attributeBindings: ["disabled", "translatedTitle:title"],

  @discourseComputed("title")
  translatedTitle(title) {
    if (title) return I18n.t(title);
  },

  click() {
    return this.attrs.action();
  }
});
