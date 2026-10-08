import dIcon from "discourse/ui-kit/helpers/d-icon";
import { i18n } from "discourse-i18n";

const DesignWizardIntroSection = <template>
  <div class="design-wizard__intro">
    <p class="design-wizard__intro-description">
      {{i18n "design_wizard.intro.description"}}
    </p>
    <p class="design-wizard__intro-note">
      {{dIcon "circle-info" class="design-wizard__intro-note-icon"}}
      <span>{{i18n "design_wizard.intro.autosave"}}</span>
    </p>
  </div>
</template>;

export default DesignWizardIntroSection;
