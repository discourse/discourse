import Component from "@ember/component";
import { action } from "@ember/object";
import { attributeBindings, classNames } from "@ember-decorators/component";
import ColorPickerChoice from "discourse/components/color-picker-choice";
import icon from "discourse/helpers/d-icon";
import { i18n } from "discourse-i18n";

@classNames("colors-container")
@attributeBindings("role", "ariaLabel:aria-label")
export default class ColorPicker extends Component {
  role = "group";

  @action
  selectColor(color) {
    this.set("value", color);
    this.onSelectColor?.(color);
  }

  @action
  getColorLabel(color) {
    const isUsed = this.usedColors?.includes(color.toUpperCase())
      ? i18n("category.color_used")
      : "";
    return `#${color} ${isUsed}`;
  }

  <template>
    {{#each this.colors as |c|}}
      <ColorPickerChoice
        @color={{c}}
        @usedColors={{this.usedColors}}
        @selectColor={{this.selectColor}}
        @ariaLabel={{this.getColorLabel c}}
      >
        {{icon "check"}}
      </ColorPickerChoice>
    {{/each}}
  </template>
}
