import Component from "@glimmer/component";
import { array, fn } from "@ember/helper";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import DMenu from "discourse/float-kit/components/d-menu";
import { HORIZON_THEME_ID } from "discourse/lib/theme-selector";
import { eq } from "discourse/truth-helpers";
import DButton from "discourse/ui-kit/d-button";
import DDropdownMenu from "discourse/ui-kit/d-dropdown-menu";
import dIcon from "discourse/ui-kit/helpers/d-icon";
import { i18n } from "discourse-i18n";

const TOPIC_PAGES = [
  { key: "latest", icon: "list" },
  { key: "hot", icon: "fire" },
  { key: "top", icon: "trophy" },
];

function topicPageLabel(page) {
  return i18n(`filters.${page}.title`);
}

function topicPageDescription(page) {
  return i18n(
    `admin_onboarding_banner.design_wizard.homepage.topic_pages.${page}`
  );
}

const TopicPageTrigger = <template>
  <button class="btn btn-default btn-icon-text" type="button" ...attributes>
    {{dIcon @icon}}
    <span class="d-button-label">{{@label}}</span>
    {{dIcon "angle-down" class="notifications-tracking-btn__caret"}}
  </button>
</template>;

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

export default class DesignWizardHomepageSection extends Component {
  get topicPageLabel() {
    return topicPageLabel(this.args.homepage);
  }

  get topicPageIcon() {
    return (
      TOPIC_PAGES.find((page) => page.key === this.args.homepage)?.icon ??
      "list"
    );
  }

  @action
  async selectTopicPage(page, dMenu) {
    await dMenu.close();
    this.args.onSelectHomepage(page);
  }

  <template>
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
        <span class="design-wizard-modal__homepage-detail-label">
          {{i18n
            "admin_onboarding_banner.design_wizard.homepage.topic_page_type"
          }}
        </span>
        <DMenu
          @identifier="design-wizard-topic-page"
          @triggerClass="btn-default btn-icon design-wizard-modal__topic-page-select"
          @contentClass="design-wizard-modal__topic-page-content"
          @modalForMobile={{true}}
          @triggerComponent={{component
            TopicPageTrigger
            label=this.topicPageLabel
            icon=this.topicPageIcon
          }}
        >
          <:content as |dMenu|>
            <DDropdownMenu
              class="design-wizard-modal__topic-page-list"
              as |dropdown|
            >
              {{#each TOPIC_PAGES as |page|}}
                <dropdown.item>
                  <DButton
                    @action={{fn this.selectTopicPage page.key dMenu}}
                    class="notifications-tracking-btn
                      {{if (eq page.key @homepage) '-selected'}}"
                    data-topic-page={{page.key}}
                  >
                    <div class="notifications-tracking-btn__icons">
                      {{dIcon page.icon}}
                    </div>
                    <div class="notifications-tracking-btn__texts">
                      <span class="notifications-tracking-btn__label">
                        {{topicPageLabel page.key}}
                      </span>
                      <span class="notifications-tracking-btn__description">
                        {{topicPageDescription page.key}}
                      </span>
                    </div>
                  </DButton>
                </dropdown.item>
              {{/each}}
            </DDropdownMenu>
          </:content>
        </DMenu>
      </div>
    {{/if}}
  </template>
}
