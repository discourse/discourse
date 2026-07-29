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
  <div class="design-wizard-modal__color">
    <div class="design-wizard-modal__color-modes">
      <button
        type="button"
        class="design-wizard-modal__color-mode
          {{if (eq @colorMode 'light') '--active'}}"
        disabled={{@darkOnly}}
        {{on "click" (fn @onSelectMode "light")}}
      >
        {{i18n "admin_onboarding_banner.design_wizard.colors.light"}}
      </button>
      <button
        type="button"
        class="design-wizard-modal__color-mode
          {{if (eq @colorMode 'dark') '--active'}}"
        {{on "click" (fn @onSelectMode "dark")}}
      >
        {{i18n "admin_onboarding_banner.design_wizard.colors.dark"}}
      </button>
    </div>
    <div class="design-wizard-modal__swatches">
      {{#each @pairs as |pair|}}
        <button
          type="button"
          class="design-wizard-modal__swatch
            {{if (eq pair.key @selectedPairKey) '--selected'}}"
          data-pair-key={{pair.key}}
          {{on "click" (fn @onSelectPair pair.key)}}
        >
          <span
            class="design-wizard-modal__swatch-preview"
            style={{swatchStyle (swatchPalette pair)}}
          ></span>
          <span class="design-wizard-modal__swatch-name">
            {{pair.name}}
            {{#if pair.dark_only}}{{dIcon "moon"}}{{/if}}
          </span>
        </button>
      {{/each}}
    </div>
    <p class="design-wizard-modal__color-note">
      {{#if @darkOnly}}
        {{i18n
          "admin_onboarding_banner.design_wizard.colors.dark_only"
          name=@selectedPairName
        }}
      {{else}}
        {{i18n "admin_onboarding_banner.design_wizard.colors.both_modes"}}
      {{/if}}
    </p>
  </div>

  <div
    class="design-wizard-modal__user-selectable"
    role="button"
    {{on "click" @onToggleUserSelectable}}
  >
    <div>
      <span class="design-wizard-modal__user-selectable-title">
        {{i18n "admin_onboarding_banner.design_wizard.colors.user_selectable"}}
      </span>
      <span class="design-wizard-modal__user-selectable-description">
        {{i18n
          "admin_onboarding_banner.design_wizard.colors.user_selectable_description"
        }}
      </span>
    </div>
    <DToggleSwitch @state={{@userSelectable}} />
  </div>
</template>;

export default DesignWizardColorsSection;
