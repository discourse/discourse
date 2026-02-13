import Component from "@glimmer/component";
import { get } from "@ember/helper";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { COLOR_NAMES } from "discourse/plugins/styleguide/discourse/services/theme-builder-state";
import ColorRow from "./color-row";

export default class ThemeBuilderColorSection extends Component {
  @service themeBuilderState;

  get colors() {
    if (this.args.mode === "dark") {
      return this.themeBuilderState.darkColors;
    }
    return this.themeBuilderState.lightColors;
  }

  get colorNames() {
    return COLOR_NAMES;
  }

  @action
  handleColorChange(name, hex) {
    if (this.args.mode === "dark") {
      this.themeBuilderState.setDarkColor(name, hex);
    } else {
      this.themeBuilderState.setLightColor(name, hex);
    }
  }

  <template>
    <div class="theme-builder-color-section">
      {{#each this.colorNames as |name|}}
        <ColorRow
          @name={{name}}
          @value={{get this.colors name}}
          @onChange={{this.handleColorChange}}
        />
      {{/each}}
    </div>
  </template>
}
