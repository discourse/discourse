import Component from "@ember/component";
import { htmlSafe } from "@ember/template";
import {
  attributeBindings,
  classNameBindings,
  tagName,
} from "@ember-decorators/component";
import discourseComputed from "discourse-common/utils/decorators";
import I18n from "discourse-i18n";

@tagName("button")
@attributeBindings("style", "title", "ariaLabel:aria-label")
@classNameBindings(":colorpicker", "isUsed:used-color:unused-color")
export default class ColorPickerChoice extends Component {
  @discourseComputed("color", "usedColors")
  isUsed(color, usedColors) {
    return (usedColors || []).includes(color.toUpperCase());
  }

  @discourseComputed("isUsed")
  title(isUsed) {
    return isUsed ? I18n.t("category.already_used") : null;
  }

  @discourseComputed("color")
  style(color) {
    return htmlSafe(`background-color: #${color};`);
  }

  click(e) {
    e.preventDefault();
    this.selectColor(this.color);
  }
}
