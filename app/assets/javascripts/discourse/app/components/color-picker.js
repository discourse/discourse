import Component from "@ember/component";
import { action } from "@ember/object";
import { attributeBindings, classNames } from "@ember-decorators/component";
import I18n from "discourse-i18n";

@classNames("colors-container")
@attributeBindings("role", "ariaLabel:aria-label")
export default class ColorPicker extends Component {
  role = "group";

  @action
  selectColor(color) {
    this.set("value", color);
  }

  @action
  getColorLabel(color) {
    const isUsed = this.usedColors?.includes(color.toUpperCase())
      ? I18n.t("category.color_used")
      : "";
    return `#${color} ${isUsed}`;
  }
}
