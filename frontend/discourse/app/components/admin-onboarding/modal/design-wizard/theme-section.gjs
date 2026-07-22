import { fn } from "@ember/helper";
import { on } from "@ember/modifier";
import PluginOutlet from "discourse/components/plugin-outlet";
import {
  FOUNDATION_THEME_ID,
  HORIZON_THEME_ID,
} from "discourse/lib/theme-selector";
import { eq } from "discourse/truth-helpers";
import { i18n } from "discourse-i18n";

function themeDescription(themeId) {
  if (themeId === HORIZON_THEME_ID) {
    return i18n(
      "admin_onboarding_banner.design_wizard.theme.horizon_description"
    );
  } else if (themeId === FOUNDATION_THEME_ID) {
    return i18n(
      "admin_onboarding_banner.design_wizard.theme.foundation_description"
    );
  }
}

function themeKey(themeId) {
  return themeId === HORIZON_THEME_ID ? "horizon" : "foundation";
}

const DesignWizardThemeSection = <template>
  <div class="design-wizard-modal__theme-cards">
    {{#each @themes as |theme|}}
      <button
        type="button"
        class="design-wizard-modal__theme-card
          {{if (eq theme.id @selectedThemeId) '--selected'}}"
        data-theme-id={{theme.id}}
        {{on "click" (fn @onSelect theme.id)}}
      >
        <span
          class="design-wizard-modal__theme-thumbnail --{{themeKey theme.id}}"
        ></span>
        <span class="design-wizard-modal__theme-name">{{theme.name}}</span>
        <span class="design-wizard-modal__theme-description">
          {{themeDescription theme.id}}
        </span>
      </button>
    {{/each}}
  </div>
  {{#if @currentTheme}}
    <p class="design-wizard-modal__custom-theme-notice">
      {{i18n
        "admin_onboarding_banner.design_wizard.theme.custom_theme_notice"
        name=@currentTheme.name
      }}
    </p>
  {{/if}}
  <PluginOutlet @name="theme-picker-modal-below-themes" />
</template>;

export default DesignWizardThemeSection;
