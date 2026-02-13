import Component from "@glimmer/component";
import { concat } from "@ember/helper";
import { action } from "@ember/object";
import ColorInput from "discourse/admin/components/color-input";
import { i18n } from "discourse-i18n";

export default class ThemeBuilderColorRow extends Component {
  @action
  onChangeColor(hex) {
    this.args.onChange?.(this.args.name, hex);
  }

  <template>
    <div class="theme-builder-color-row">
      <label class="theme-builder-color-row__label">
        {{i18n (concat "styleguide.theme_builder.colors." @name)}}
      </label>
      <ColorInput @hexValue={{@value}} @onChangeColor={{this.onChangeColor}} />
    </div>
  </template>
}
