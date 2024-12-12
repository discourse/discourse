import Component from "@glimmer/component";
import { hash } from "@ember/helper";
import { action, set } from "@ember/object";
import ColorPalettes from "select-kit/components/color-palettes";
import ComboBox from "select-kit/components/combo-box";
import FontSelector from "select-kit/components/font-selector";

export default class Dropdown extends Component {
  constructor() {
    super(...arguments);

    if (this.args.field.id === "color_scheme") {
      for (let choice of this.args.field.choices) {
        if (choice?.data?.colors) {
          set(choice, "colors", choice.data.colors);
        }
      }
    }

    if (this.args.field.id === "body_font") {
      for (let choice of this.args.field.choices) {
        set(choice, "classNames", `body-font-${choice.id.replace(/_/g, "-")}`);
      }
    }

    if (this.args.field.id === "heading_font") {
      for (let choice of this.args.field.choices) {
        set(
          choice,
          "classNames",
          `heading-font-${choice.id.replace(/_/g, "-")}`
        );
      }
    }
  }

  get component() {
    switch (this.args.field.id) {
      case "color_scheme":
        return ColorPalettes;
      case "body_font":
      case "heading_font":
        return FontSelector;
      default:
        return ComboBox;
    }
  }

  keyPress(event) {
    event.stopPropagation();
  }

  @action
  onChangeValue(value) {
    this.set("field.value", value);
  }

  <template>
    {{component
      this.component
      class="wizard-container__dropdown"
      value=@field.value
      content=@field.choices
      nameProperty="label"
      tabindex="9"
      onChange=this.onChangeValug
      options=(hash translatedNone=false)
    }}
  </template>
}
