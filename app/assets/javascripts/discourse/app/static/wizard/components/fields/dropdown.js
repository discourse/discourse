import Component from "@ember/component";
import { action, set } from "@ember/object";
import discourseComputed from "discourse-common/utils/decorators";
import ColorPalettes from "select-kit/components/color-palettes";
import ComboBox from "select-kit/components/combo-box";

export default class Dropdown extends Component {
  init() {
    super.init(...arguments);

    if (this.field.id === "color_scheme") {
      for (let choice of this.field.choices) {
        if (choice?.data?.colors) {
          set(choice, "colors", choice.data.colors);
        }
      }
    }
  }

  @discourseComputed("field.id")
  component(id) {
    return id === "color_scheme" ? ColorPalettes : ComboBox;
  }

  keyPress(e) {
    e.stopPropagation();
  }

  @action
  onChangeValue(value) {
    this.set("field.value", value);
  }
}
