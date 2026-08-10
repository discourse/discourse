import { array, fn } from "@ember/helper";
import { on } from "@ember/modifier";
import { HORIZON_THEME_ID } from "discourse/lib/theme-selector";
import { eq } from "discourse/truth-helpers";
import { i18n } from "discourse-i18n";

const TOPIC_PAGES = ["latest", "new", "hot"];

function topicPageLabel(page) {
  return i18n(`filters.${page}.title`);
}

function topicPageDescription(page) {
  return i18n(`design_wizard.homepage.topic_pages.${page}`);
}

function isHorizon(themeId) {
  return themeId === HORIZON_THEME_ID;
}

const TopicsMock = <template>
  {{#if (isHorizon @themeId)}}
    {{#each (array 1 2)}}
      <span class="design-wizard__mock-card">
        <span class="design-wizard__mock-avatar"></span>
        <span class="design-wizard__mock-line --title"></span>
        <span class="design-wizard__mock-line --text"></span>
        <span class="design-wizard__mock-badge"></span>
      </span>
    {{/each}}
  {{else}}
    {{#each (array 1 2 3 4)}}
      <span class="design-wizard__mock-row">
        <span class="design-wizard__mock-line --title"></span>
        <span class="design-wizard__mock-avatar"></span>
        <span class="design-wizard__mock-line --count"></span>
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
  return i18n(`design_wizard.homepage.styles.${kind.replaceAll("-", "_")}`);
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

const CategoriesMock = <template>
  {{#each (array "c1" "c2" "c3" "c4") as |box|}}
    <span class="design-wizard__mock-box --{{box}}">
      <span class="design-wizard__mock-line --title"></span>
      <span class="design-wizard__mock-line --text"></span>
      <span class="design-wizard__mock-line --text"></span>
    </span>
  {{/each}}
</template>;

const CategoryStyleMock = <template>
  {{#if (eq @kind "boxes")}}
    <CategoriesMock />
  {{else if (eq @kind "only")}}
    {{#each (array "c1" "c2" "c3" "c4") as |row|}}
      <span class="design-wizard__mock-row">
        <span class="design-wizard__mock-cat-badge --{{row}}"></span>
        <span class="design-wizard__mock-line --title"></span>
        <span class="design-wizard__mock-line --count"></span>
      </span>
    {{/each}}
  {{else}}
    <span class="design-wizard__mock-columns">
      <span class="design-wizard__mock-column">
        {{#each (array "c1" "c2" "c3") as |row|}}
          <span class="design-wizard__mock-row">
            <span class="design-wizard__mock-cat-badge --{{row}}"></span>
            <span class="design-wizard__mock-line --title"></span>
          </span>
        {{/each}}
      </span>
      <span class="design-wizard__mock-column">
        {{#each (array 1 2 3)}}
          <span class="design-wizard__mock-row">
            <span class="design-wizard__mock-avatar"></span>
            <span class="design-wizard__mock-line --title"></span>
          </span>
        {{/each}}
      </span>
    </span>
  {{/if}}
</template>;

const DesignWizardHomepageSection = <template>
  <div class="design-wizard__homepage-cards">
    <button
      type="button"
      class="design-wizard__homepage-card
        {{unless (eq @homepage 'categories') '--selected'}}"
      aria-pressed={{if (eq @homepage "categories") "false" "true"}}
      data-homepage="topics"
      {{on "click" (fn @onSelectHomepage "latest")}}
    >
      <span
        class="design-wizard__homepage-thumbnail --topics
          {{if (isHorizon @themeId) '--horizon'}}"
      >
        <TopicsMock @themeId={{@themeId}} />
      </span>
      {{i18n "design_wizard.homepage.topics"}}
    </button>
    <button
      type="button"
      class="design-wizard__homepage-card
        {{if (eq @homepage 'categories') '--selected'}}"
      aria-pressed={{if (eq @homepage "categories") "true" "false"}}
      data-homepage="categories"
      {{on "click" (fn @onSelectHomepage "categories")}}
    >
      <span class="design-wizard__homepage-thumbnail --categories">
        <CategoriesMock />
      </span>
      {{i18n "design_wizard.homepage.categories"}}
    </button>
  </div>

  {{#if (eq @homepage "categories")}}
    <div class="design-wizard__homepage-detail">
      <span class="design-wizard__label">
        {{i18n "design_wizard.homepage.category_page_style"}}
      </span>
      <div class="design-wizard__style-blocks">
        {{#let (categoryStyleKind @categoryPageStyle) as |selectedKind|}}
          {{#each CATEGORY_STYLE_OPTIONS as |option|}}
            <button
              type="button"
              class="design-wizard__style-block
                {{if (eq selectedKind option.kind) '--selected'}}"
              aria-pressed={{if (eq selectedKind option.kind) "true" "false"}}
              data-style={{option.value}}
              {{on "click" (fn @onSelectCategoryPageStyle option.value)}}
            >
              <span
                class="design-wizard__homepage-style-preview
                  {{if (eq option.kind 'boxes') '--boxes'}}"
              >
                <CategoryStyleMock @kind={{option.kind}} />
              </span>
              {{categoryStyleLabel option.kind}}
            </button>
          {{/each}}
        {{/let}}
      </div>
    </div>
  {{else}}
    <div class="design-wizard__homepage-detail">
      <span class="design-wizard__label">
        {{i18n "design_wizard.homepage.topic_page_type"}}
      </span>
      <div class="design-wizard__topic-page-options">
        {{#each TOPIC_PAGES as |page|}}
          <button
            type="button"
            class="design-wizard__topic-page-option
              {{if (eq page @homepage) '--selected'}}"
            aria-pressed={{if (eq page @homepage) "true" "false"}}
            data-topic-page={{page}}
            {{on "click" (fn @onSelectHomepage page)}}
          >
            <span class="design-wizard__topic-page-option-texts">
              <span class="design-wizard__topic-page-option-label">
                {{topicPageLabel page}}
              </span>
              <span class="design-wizard__topic-page-option-description">
                {{topicPageDescription page}}
              </span>
            </span>
          </button>
        {{/each}}
      </div>
    </div>
  {{/if}}
</template>;

export default DesignWizardHomepageSection;
