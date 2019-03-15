import computed from "ember-addons/ember-computed-decorators";

export default Ember.Component.extend({
  tagName: "button",
  attributeBindings: ["style", "title"],
  classNameBindings: [":colorpicker", "isUsed:used-color:unused-color"],

  @computed("color", "usedColors")
  isUsed(color, usedColors) {
    return (usedColors || []).indexOf(color.toUpperCase()) >= 0;
  },

  @computed("isUsed")
  title(isUsed) {
    return isUsed ? I18n.t("category.already_used") : null;
  },

  @computed("color")
  style(color) {
    return `background-color: #${color};`.htmlSafe();
  },

  click(e) {
    e.preventDefault();
    this.selectColor(this.get("color"));
  }
});
