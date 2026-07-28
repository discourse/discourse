import { fn } from "@ember/helper";
import { on } from "@ember/modifier";
import PluginOutlet from "discourse/components/plugin-outlet";
import ThemeCardPreview from "discourse/components/theme-card-preview";
import {
  FOUNDATION_THEME_ID,
  HORIZON_THEME_ID,
} from "discourse/lib/theme-selector";
import { eq } from "discourse/truth-helpers";
import dIcon from "discourse/ui-kit/helpers/d-icon";
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

const DesignWizardThemeSection = <template>
  <div class="design-wizard-modal__theme-cards">
    {{#each @themes as |theme|}}
      <div
        class="design-wizard-modal__theme-card
          {{if (eq theme.id @selectedThemeId) '--selected'}}"
        data-theme-id={{theme.id}}
        role="button"
        {{on "click" (fn @onSelect theme.id)}}
      >
        {{#if (eq theme.id @selectedThemeId)}}
          <span class="design-wizard-modal__theme-enabled-badge">
            {{dIcon "check"}}
            {{i18n "admin_onboarding_banner.design_wizard.theme.selected"}}
          </span>
        {{/if}}
        <ThemeCardPreview @theme={{theme}} />
        <span class="design-wizard-modal__theme-description">
          {{themeDescription theme.id}}
        </span>
      </div>
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
