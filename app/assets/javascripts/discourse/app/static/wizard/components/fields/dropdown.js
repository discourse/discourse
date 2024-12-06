import Component from "@ember/component";
import { action, set } from "@ember/object";
import discourseComputed from "discourse-common/utils/decorators";
import ColorPalettes from "select-kit/components/color-palettes";
import ComboBox from "select-kit/components/combo-box";
import FontSelector from "select-kit/components/font-selector";

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

    // TODO (martin) Maybe add a test for this, even if it's a component one.
    if (this.field.id === "body_font") {
      for (let choice of this.field.choices) {
        set(choice, "classNames", `body-font-${choice.id.replace(/_/g, "-")}`);
      }
    }

    if (this.field.id === "heading_font") {
      for (let choice of this.field.choices) {
        set(
          choice,
          "classNames",
          `heading-font-${choice.id.replace(/_/g, "-")}`
        );
      }
    }
  }

  @discourseComputed("field.id")
  component(id) {
    switch (id) {
      case "color_scheme":
        return ColorPalettes;
      case "body_font":
      case "heading_font":
        return FontSelector;
      default:
        return ComboBox;
    }
  }

  keyPress(e) {
    e.stopPropagation();
  }

  @action
  onChangeValue(value) {
    this.set("field.value", value);
  }
}
