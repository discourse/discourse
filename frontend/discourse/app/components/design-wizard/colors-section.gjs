import { fn } from "@ember/helper";
import { on } from "@ember/modifier";
import { swatchStyle } from "discourse/lib/design-wizard-preview";
import { eq } from "discourse/truth-helpers";
import DToggleSwitch from "discourse/ui-kit/d-toggle-switch";
import dIcon from "discourse/ui-kit/helpers/d-icon";
import { i18n } from "discourse-i18n";

function swatchPalette(pair) {
  return pair.light ?? pair.dark;
}

const DesignWizardColorsSection = <template>
  <div class="design-wizard__color">
    <div class="design-wizard__color-modes">
      <button
        type="button"
        class="design-wizard__color-mode
          {{if (eq @colorMode 'light') '--active'}}"
        aria-pressed={{if (eq @colorMode "light") "true" "false"}}
        disabled={{@darkOnly}}
        {{on "click" (fn @onSelectMode "light")}}
      >
        {{i18n "design_wizard.colors.light"}}
      </button>
      <button
        type="button"
        class="design-wizard__color-mode
          {{if (eq @colorMode 'dark') '--active'}}"
        aria-pressed={{if (eq @colorMode "dark") "true" "false"}}
        {{on "click" (fn @onSelectMode "dark")}}
      >
        {{i18n "design_wizard.colors.dark"}}
      </button>
    </div>
    <div class="design-wizard__swatches">
      {{#each @pairs as |pair|}}
        <button
          type="button"
          class="design-wizard__swatch
            {{if (eq pair.key @selectedPairKey) '--selected'}}"
          aria-pressed={{if (eq pair.key @selectedPairKey) "true" "false"}}
          data-pair-key={{pair.key}}
          {{on "click" (fn @onSelectPair pair.key)}}
        >
          <span
            class="design-wizard__swatch-preview"
            style={{swatchStyle (swatchPalette pair)}}
          ></span>
          <span class="design-wizard__swatch-name">
            {{pair.name}}
            {{#if pair.dark_only}}{{dIcon "moon"}}{{/if}}
          </span>
        </button>
      {{/each}}
    </div>
    <p class="design-wizard__color-note">
      {{#if @darkOnly}}
        {{i18n "design_wizard.colors.dark_only" name=@selectedPairName}}
      {{else}}
        {{i18n "design_wizard.colors.both_modes"}}
      {{/if}}
    </p>
  </div>

  <div class="design-wizard__switch-row">
    <div>
      <span
        id="design-wizard-user-selectable-title"
        class="design-wizard__switch-row-title"
      >
        {{i18n "design_wizard.colors.user_selectable"}}
      </span>
      <span
        id="design-wizard-user-selectable-description"
        class="design-wizard__switch-row-description"
      >
        {{i18n "design_wizard.colors.user_selectable_description"}}
      </span>
    </div>
    <DToggleSwitch
      @state={{@userSelectable}}
      aria-labelledby="design-wizard-user-selectable-title"
      aria-describedby="design-wizard-user-selectable-description"
      {{on "click" @onToggleUserSelectable}}
    />
  </div>
</template>;

export default DesignWizardColorsSection;
