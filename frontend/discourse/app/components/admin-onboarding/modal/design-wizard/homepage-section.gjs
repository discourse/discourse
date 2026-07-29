import { array, fn } from "@ember/helper";
import { on } from "@ember/modifier";
import { HORIZON_THEME_ID } from "discourse/lib/theme-selector";
import { eq } from "discourse/truth-helpers";
import DSelect from "discourse/ui-kit/d-select";
import { i18n } from "discourse-i18n";

const TOPIC_PAGES = ["latest", "top", "hot"];

function topicPageLabel(page) {
  return i18n(`filters.${page}.title`);
}

function isHorizon(themeId) {
  return themeId === HORIZON_THEME_ID;
}

const TopicsMock = <template>
  {{#if (isHorizon @themeId)}}
    {{#each (array 1 2) as |card|}}
      <span class="design-wizard-modal__mock-card" data-card={{card}}>
        <span class="design-wizard-modal__mock-avatar"></span>
        <span class="design-wizard-modal__mock-line --title"></span>
        <span class="design-wizard-modal__mock-line --text"></span>
        <span class="design-wizard-modal__mock-badge"></span>
      </span>
    {{/each}}
  {{else}}
    {{#each (array 1 2 3 4) as |row|}}
      <span class="design-wizard-modal__mock-row" data-row={{row}}>
        <span class="design-wizard-modal__mock-line --title"></span>
        <span class="design-wizard-modal__mock-avatar"></span>
        <span class="design-wizard-modal__mock-line --count"></span>
      </span>
    {{/each}}
  {{/if}}
</template>;

const CATEGORY_STYLE_OPTIONS = [
  { value: "categories_boxes", kind: "boxes" },
  { value: "categories_and_latest_topics", kind: "with-topics" },
  { value: "categories_only", kind: "only" },
];

function categoryStyleLabel(kind) {
  return i18n(
    `admin_onboarding_banner.design_wizard.homepage.styles.${kind.replaceAll(
      "-",
      "_"
    )}`
  );
}

function categoryStyleKind(style) {
  if (style === "categories_only") {
    return "only";
  }

  if (style?.startsWith("categories_boxes")) {
    return "boxes";
  }

  return "with-topics";
}

const CategoryStyleMock = <template>
  {{#if (eq (categoryStyleKind @style) "boxes")}}
    <CategoriesMock />
  {{else if (eq (categoryStyleKind @style) "only")}}
    {{#each (array "c1" "c2" "c3" "c4") as |row|}}
      <span class="design-wizard-modal__mock-row">
        <span class="design-wizard-modal__mock-cat-badge --{{row}}"></span>
        <span class="design-wizard-modal__mock-line --title"></span>
        <span class="design-wizard-modal__mock-line --count"></span>
      </span>
    {{/each}}
  {{else}}
    <span class="design-wizard-modal__mock-columns">
      <span class="design-wizard-modal__mock-column">
        {{#each (array "c1" "c2" "c3") as |row|}}
          <span class="design-wizard-modal__mock-row">
            <span class="design-wizard-modal__mock-cat-badge --{{row}}"></span>
            <span class="design-wizard-modal__mock-line --title"></span>
          </span>
        {{/each}}
      </span>
      <span class="design-wizard-modal__mock-column">
        {{#each (array 1 2 3) as |row|}}
          <span class="design-wizard-modal__mock-row" data-row={{row}}>
            <span class="design-wizard-modal__mock-avatar"></span>
            <span class="design-wizard-modal__mock-line --title"></span>
          </span>
        {{/each}}
      </span>
    </span>
  {{/if}}
</template>;

const CategoriesMock = <template>
  {{#each (array "c1" "c2" "c3" "c4") as |box|}}
    <span class="design-wizard-modal__mock-box --{{box}}">
      <span class="design-wizard-modal__mock-line --title"></span>
      <span class="design-wizard-modal__mock-line --text"></span>
      <span class="design-wizard-modal__mock-line --text"></span>
    </span>
  {{/each}}
</template>;

const DesignWizardHomepageSection = <template>
  <div class="design-wizard-modal__homepage-cards">
    <button
      type="button"
      class="design-wizard-modal__homepage-card
        {{unless (eq @homepage 'categories') '--selected'}}"
      data-homepage="topics"
      {{on "click" (fn @onSelectHomepage "latest")}}
    >
      <span
        class="design-wizard-modal__homepage-thumbnail --topics
          {{if (isHorizon @themeId) '--horizon' '--foundation'}}"
      >
        <TopicsMock @themeId={{@themeId}} />
      </span>
      {{i18n "admin_onboarding_banner.design_wizard.homepage.topics"}}
    </button>
    <button
      type="button"
      class="design-wizard-modal__homepage-card
        {{if (eq @homepage 'categories') '--selected'}}"
      data-homepage="categories"
      {{on "click" (fn @onSelectHomepage "categories")}}
    >
      <span class="design-wizard-modal__homepage-thumbnail --categories">
        <CategoriesMock />
      </span>
      {{i18n "admin_onboarding_banner.design_wizard.homepage.categories"}}
    </button>
  </div>

  {{#if (eq @homepage "categories")}}
    <div class="design-wizard-modal__homepage-detail">
      <span class="design-wizard-modal__homepage-detail-label">
        {{i18n
          "admin_onboarding_banner.design_wizard.homepage.category_page_style"
        }}
      </span>
      <div class="design-wizard-modal__style-blocks">
        {{#each CATEGORY_STYLE_OPTIONS as |option|}}
          <button
            type="button"
            class="design-wizard-modal__style-block
              {{if
                (eq (categoryStyleKind @categoryPageStyle) option.kind)
                '--selected'
              }}"
            data-style={{option.value}}
            {{on "click" (fn @onSelectCategoryPageStyle option.value)}}
          >
            <span
              class="design-wizard-modal__homepage-style-preview
                {{if (eq option.kind 'boxes') '--boxes'}}"
            >
              <CategoryStyleMock @style={{option.value}} />
            </span>
            {{categoryStyleLabel option.kind}}
          </button>
        {{/each}}
      </div>
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
