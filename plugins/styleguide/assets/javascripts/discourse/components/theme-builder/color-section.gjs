import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { get } from "@ember/helper";
import { action } from "@ember/object";
import { service } from "@ember/service";
import DButton from "discourse/components/d-button";
import { i18n } from "discourse-i18n";
import ColorRow from "./color-row";

const MAIN_COLOR_NAMES = [
  "primary",
  "secondary",
  "tertiary",
  "selected",
  "hover",
  "header_background",
  "header_primary",
];

const ADVANCED_COLOR_NAMES = [
  "quaternary",
  "highlight",
  "danger",
  "success",
  "love",
];

export default class ThemeBuilderColorSection extends Component {
  @service themeBuilderState;

  @tracked advancedExpanded = false;

  get colors() {
    if (this.args.mode === "dark") {
      return this.themeBuilderState.darkColors;
    }
    return this.themeBuilderState.lightColors;
  }

  @action
  handleColorChange(name, hex) {
    if (this.args.mode === "dark") {
      this.themeBuilderState.setDarkColor(name, hex);
    } else {
      this.themeBuilderState.setLightColor(name, hex);
    }
  }

  @action
  toggleAdvanced() {
    this.advancedExpanded = !this.advancedExpanded;
  }

  <template>
    <div class="theme-builder-color-section">
      {{#each MAIN_COLOR_NAMES as |name|}}
        <ColorRow
          @name={{name}}
          @value={{get this.colors name}}
          @onChange={{this.handleColorChange}}
        />
      {{/each}}

      <div class="theme-builder-color-section__advanced">
        <DButton
          class="theme-builder-color-section__advanced-toggle btn-transparent"
          @action={{this.toggleAdvanced}}
          @icon={{if this.advancedExpanded "angle-down" "angle-right"}}
          @translatedLabel={{i18n "styleguide.theme_builder.colors.advanced"}}
        />

        {{#if this.advancedExpanded}}
          {{#each ADVANCED_COLOR_NAMES as |name|}}
            <ColorRow
              @name={{name}}
              @value={{get this.colors name}}
              @onChange={{this.handleColorChange}}
            />
          {{/each}}
        {{/if}}
      </div>
    </div>
  </template>
}
