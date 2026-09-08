/* eslint-disable ember/no-classic-components */
import Component from "@ember/component";
import { action } from "@ember/object";
import { tagName } from "@ember-decorators/component";
import DColorPickerChoice from "discourse/ui-kit/d-color-picker-choice";
import dIcon from "discourse/ui-kit/helpers/d-icon";
import { i18n } from "discourse-i18n";

@tagName("")
export default class DColorPicker extends Component {
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
    <div
      aria-label={{this.ariaLabel}}
      class="colors-container"
      role={{this.role}}
      ...attributes
    >
      {{#each this.colors as |c|}}
        <DColorPickerChoice
          @ariaLabel={{this.getColorLabel c}}
          @color={{c}}
          @selectColor={{this.selectColor}}
          @usedColors={{this.usedColors}}
        >
          {{dIcon "check"}}
        </DColorPickerChoice>
      {{/each}}
    </div>
  </template>
}
