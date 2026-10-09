import { fn } from "@ember/helper";
import { on } from "@ember/modifier";
import OptionRow from "discourse/components/design-wizard/option-row";
import { eq } from "discourse/truth-helpers";
import DToggleSwitch from "discourse/ui-kit/d-toggle-switch";
import { i18n } from "discourse-i18n";

const LOCATIONS = ["below_site_header", "above_topic_content"];

function locationLabel(location) {
  return i18n(`design_wizard.welcome_banner.locations.${location}`);
}

const DesignWizardWelcomeBannerSection = <template>
  <div class="design-wizard__switch-row">
    <div>
      <span
        class="design-wizard__switch-row-title"
        id="design-wizard-welcome-banner-title"
      >
        {{i18n "design_wizard.welcome_banner.enable"}}
      </span>
      <span
        class="design-wizard__switch-row-description"
        id="design-wizard-welcome-banner-description"
      >
        {{i18n "design_wizard.welcome_banner.enable_description"}}
      </span>
    </div>
    <DToggleSwitch
      aria-describedby="design-wizard-welcome-banner-description"
      aria-labelledby="design-wizard-welcome-banner-title"
      @state={{@enabled}}
      {{on "click" @onToggle}}
    />
  </div>

  {{#if @enabled}}
    <div class="design-wizard__detail-group">
      <span class="design-wizard__label">
        {{i18n "design_wizard.welcome_banner.location"}}
      </span>
      <div class="design-wizard__option-rows">
        {{#each LOCATIONS as |location|}}
          <OptionRow
            data-welcome-banner-location={{location}}
            @label={{locationLabel location}}
            @onSelect={{fn @onSelectLocation location}}
            @selected={{eq location @location}}
          />
        {{/each}}
      </div>
    </div>
  {{/if}}
</template>;

export default DesignWizardWelcomeBannerSection;
