import { fn } from "@ember/helper";
import OptionRow from "discourse/components/design-wizard/option-row";
import { eq } from "discourse/truth-helpers";
import { i18n } from "discourse-i18n";

const EXPERIENCES = ["search_icon", "search_field"];

function experienceLabel(experience) {
  return i18n(`design_wizard.search.experiences.${experience}.title`);
}

function experienceDescription(experience) {
  return i18n(`design_wizard.search.experiences.${experience}.description`);
}

const DesignWizardSearchSection = <template>
  <div class="design-wizard__option-rows">
    {{#each EXPERIENCES as |experience|}}
      <OptionRow
        data-search-experience={{experience}}
        @description={{experienceDescription experience}}
        @label={{experienceLabel experience}}
        @onSelect={{fn @onSelect experience}}
        @selected={{eq experience @searchExperience}}
      />
    {{/each}}
  </div>
</template>;

export default DesignWizardSearchSection;
