import { fn } from "@ember/helper";
import { on } from "@ember/modifier";
import { eq } from "discourse/truth-helpers";
import DSelect from "discourse/ui-kit/d-select";
import { i18n } from "discourse-i18n";

const TOPIC_PAGES = ["latest", "top", "hot"];

function topicPageLabel(page) {
  return i18n(`filters.${page}.title`);
}

const DesignWizardHomepageSection = <template>
  <div class="design-wizard-modal__homepage-cards">
    <button
      type="button"
      class="design-wizard-modal__homepage-card
        {{unless (eq @homepage 'categories') '--selected'}}"
      data-homepage="topics"
      {{on "click" (fn @onSelectHomepage "latest")}}
    >
      <span class="design-wizard-modal__homepage-thumbnail --topic-list"></span>
      {{i18n "admin_onboarding_banner.design_wizard.homepage.topics"}}
    </button>
    <button
      type="button"
      class="design-wizard-modal__homepage-card
        {{if (eq @homepage 'categories') '--selected'}}"
      data-homepage="categories"
      {{on "click" (fn @onSelectHomepage "categories")}}
    >
      <span class="design-wizard-modal__homepage-thumbnail --categories"></span>
      {{i18n "admin_onboarding_banner.design_wizard.homepage.categories"}}
    </button>
  </div>

  {{#if (eq @homepage "categories")}}
    <div class="design-wizard-modal__homepage-detail">
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
      <p class="design-wizard-modal__homepage-note">
        {{i18n
          "admin_onboarding_banner.design_wizard.homepage.category_page_style_note"
        }}
      </p>
    </div>
  {{else}}
    <div class="design-wizard-modal__homepage-detail">
      <label for="design-wizard-topic-page">
        {{i18n
          "admin_onboarding_banner.design_wizard.homepage.topic_page_type"
        }}
      </label>
      <DSelect
        @value={{@homepage}}
        @onChange={{@onSelectHomepage}}
        @includeNone={{false}}
        id="design-wizard-topic-page"
        as |select|
      >
        {{#each TOPIC_PAGES as |page|}}
          <select.Option @value={{page}}>
            {{topicPageLabel page}}
          </select.Option>
        {{/each}}
      </DSelect>
    </div>
  {{/if}}
</template>;

export default DesignWizardHomepageSection;
