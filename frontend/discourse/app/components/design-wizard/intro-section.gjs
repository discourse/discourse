import DButton from "discourse/ui-kit/d-button";
import dIcon from "discourse/ui-kit/helpers/d-icon";
import { i18n } from "discourse-i18n";

const DesignWizardIntroSection = <template>
  <div class="design-wizard__intro">
    <p class="design-wizard__intro-description">
      {{i18n "design_wizard.intro.description"}}
    </p>
    <p class="design-wizard__intro-note">
      {{dIcon "circle-info" class="design-wizard__intro-note-icon"}}
      <span>
        {{i18n "design_wizard.intro.autosave"}}
        {{if
          @revertable
          (i18n "design_wizard.intro.revert_available")
          (i18n "design_wizard.intro.revert_unavailable")
        }}
      </span>
    </p>
    <DButton
      @action={{@onStart}}
      @label="design_wizard.intro.start"
      class="btn-primary design-wizard__intro-start"
    />
  </div>
</template>;

export default DesignWizardIntroSection;
