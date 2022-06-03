import Component from "@ember/component";
import discourseComputed from "discourse-common/utils/decorators";
import { set } from "@ember/object";

export default Component.extend({
  init(...args) {
    this._super(...args);

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
    if (id === "color_scheme") {
      return "color-palettes";
    }
    return "combo-box";
  },

  keyPress(e) {
    e.stopPropagation();
  },

  actions: {
    onChangeValue(value) {
      this.set("field.value", value);

      if (this.field.id === "homepage_style") {
        this.wizard.trigger("homepageStyleChanged");
      }
    },
  },
});
