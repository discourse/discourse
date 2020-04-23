import discourseComputed from "discourse-common/utils/decorators";
import Component from "@ember/component";

export default Component.extend({
  tagName: "button",
  attributeBindings: ["style", "title"],
  classNameBindings: [":colorpicker", "isUsed:used-color:unused-color"],

  @discourseComputed("color", "usedColors")
  isUsed(color, usedColors) {
    return (usedColors || []).indexOf(color.toUpperCase()) >= 0;
  },

  @discourseComputed("isUsed")
  title(isUsed) {
    return isUsed ? I18n.t("category.already_used") : null;
  },

  @discourseComputed("color")
  style(color) {
    return `background-color: #${color};`.htmlSafe();
  },

  click(e) {
    e.preventDefault();
    this.selectColor(this.color);
  }
});
