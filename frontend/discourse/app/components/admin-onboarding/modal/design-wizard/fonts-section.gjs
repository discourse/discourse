import { fn } from "@ember/helper";
import { on } from "@ember/modifier";
import { MAIN_FONTS } from "discourse/admin/lib/constants";
import { fontClass } from "discourse/lib/design-wizard-preview";
import getURL from "discourse/lib/get-url";
import { eq } from "discourse/truth-helpers";
import { i18n } from "discourse-i18n";

const DesignWizardFontsSection = <template>
  <div class="design-wizard-modal__font-group">
    <span class="design-wizard-modal__font-group-label">
      {{i18n "admin_onboarding_banner.design_wizard.fonts.body"}}
    </span>
    <div class="design-wizard-modal__font-cards">
      {{#each MAIN_FONTS as |font|}}
        <button
          type="button"
          class="design-wizard-modal__font-card
            {{fontClass font.key}}
            {{if (eq font.key @bodyFont) '--selected'}}"
          {{on "click" (fn @onSelectBodyFont font.key)}}
        >
          {{font.name}}
        </button>
      {{/each}}
    </div>
  </div>

  <div class="design-wizard-modal__font-group">
    <span class="design-wizard-modal__font-group-label">
      {{i18n "admin_onboarding_banner.design_wizard.fonts.headings"}}
    </span>
    <div class="design-wizard-modal__font-cards">
      {{#each MAIN_FONTS as |font|}}
        <button
          type="button"
          class="design-wizard-modal__font-card
            {{fontClass font.key}}
            {{if (eq font.key @headingFont) '--selected'}}"
          {{on "click" (fn @onSelectHeadingFont font.key)}}
        >
          {{font.name}}
        </button>
      {{/each}}
    </div>
  </div>

  <p class="design-wizard-modal__fonts-note">
    <a href={{getURL "/admin/config/fonts"}}>
      {{i18n "admin_onboarding_banner.design_wizard.fonts.more_fonts"}}
    </a>
  </p>
</template>;

export default DesignWizardFontsSection;
