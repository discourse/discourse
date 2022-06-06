import Component from "@ember/component";
import discourseComputed from "discourse-common/utils/decorators";
import { action, set } from "@ember/object";

export default Component.extend({
  init() {
    this._super(...arguments);

    if (this.field.id === "color_scheme") {
      for (let choice of this.field.choices) {
        if (choice?.data?.colors) {
          set(choice, "colors", choice.data.colors);
        }
      }
    }
  },

  @discourseComputed("field.id")
  componentName(id) {
    return id === "color_scheme" ? "color-palettes" : "combo-box";
  },

  keyPress(e) {
    e.stopPropagation();
  },

  @action
  onChangeValue(value) {
    this.set("field.value", value);

    if (this.field.id === "homepage_style") {
      this.wizard.trigger("homepageStyleChanged");
    }
  },
});
