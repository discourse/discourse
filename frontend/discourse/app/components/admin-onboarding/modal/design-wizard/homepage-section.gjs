import { fn } from "@ember/helper";
import { on } from "@ember/modifier";
import { eq } from "discourse/truth-helpers";
import DSelect from "discourse/ui-kit/d-select";
import { i18n } from "discourse-i18n";

const DesignWizardHomepageSection = <template>
  <div class="design-wizard-modal__homepage-cards">
    <button
      type="button"
      class="design-wizard-modal__homepage-card
        {{if (eq @homepage 'latest') '--selected'}}"
      {{on "click" (fn @onSelectHomepage "latest")}}
    >
      <span class="design-wizard-modal__homepage-thumbnail --topic-list"></span>
      {{i18n "admin_onboarding_banner.design_wizard.homepage.topic_list"}}
    </button>
    <button
      type="button"
      class="design-wizard-modal__homepage-card
        {{if (eq @homepage 'categories') '--selected'}}"
      {{on "click" (fn @onSelectHomepage "categories")}}
    >
      <span class="design-wizard-modal__homepage-thumbnail --categories"></span>
      {{i18n "admin_onboarding_banner.design_wizard.homepage.categories"}}
    </button>
  </div>

  {{#if (eq @homepage "categories")}}
    <div class="design-wizard-modal__category-page-style">
      <label for="design-wizard-category-page-style">
        {{i18n
          "admin_onboarding_banner.design_wizard.homepage.category_page_style"
        }}
      </label>
      <DSelect
        @value={{@categoryPageStyle}}
        @onChange={{@onSelectCategoryPageStyle}}
        @includeNone={{false}}
        id="design-wizard-category-page-style"
        as |select|
      >
        {{#each @categoryPageStyles as |style|}}
          <select.Option @value={{style.value}}>
            {{i18n style.name}}
          </select.Option>
        {{/each}}
      </DSelect>
    </div>
  {{/if}}
</template>;

export default DesignWizardHomepageSection;
