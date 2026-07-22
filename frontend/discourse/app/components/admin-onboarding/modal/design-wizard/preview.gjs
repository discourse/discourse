import Component from "@glimmer/component";
import { service } from "@ember/service";
import { trustHTML } from "@ember/template";
import { fontClass, previewStyle } from "discourse/lib/design-wizard-preview";
import { eq } from "discourse/truth-helpers";
import dIcon from "discourse/ui-kit/helpers/d-icon";
import { i18n } from "discourse-i18n";

function badgeStyle(color) {
  return trustHTML(`background-color: #${color}`);
}

function boxStyle(color) {
  return trustHTML(`border-top-color: #${color}`);
}

export default class DesignWizardPreview extends Component {
  @service siteSettings;

  get style() {
    return previewStyle({
      colors: this.args.palette?.colors,
      themeId: this.args.themeId,
    });
  }

  get contentVariant() {
    if (this.args.homepage !== "categories") {
      return "topic-list";
    }

    if (this.args.categoryPageStyle?.startsWith("categories_boxes")) {
      return "category-boxes";
    } else if (this.args.categoryPageStyle === "categories_only") {
      return "categories-only";
    }

    return "categories-with-topics";
  }

  get sampleTopics() {
    return [
      i18n("admin_onboarding_banner.design_wizard.preview.sample_topic_1"),
      i18n("admin_onboarding_banner.design_wizard.preview.sample_topic_2"),
      i18n("admin_onboarding_banner.design_wizard.preview.sample_topic_3"),
    ];
  }

  get sampleCategories() {
    return [
      {
        name: i18n(
          "admin_onboarding_banner.design_wizard.preview.sample_category_1"
        ),
        color: "25aae2",
      },
      {
        name: i18n(
          "admin_onboarding_banner.design_wizard.preview.sample_category_2"
        ),
        color: "9eb83b",
      },
      {
        name: i18n(
          "admin_onboarding_banner.design_wizard.preview.sample_category_3"
        ),
        color: "e45735",
      },
    ];
  }

  <template>
    <div class="design-wizard-modal__preview" style={{this.style}}>
      <div class="design-wizard-modal__preview-label">
        {{dIcon "far-eye"}}
        {{i18n "admin_onboarding_banner.design_wizard.preview.label"}}
      </div>
      <div
        class="design-wizard-modal__preview-site {{fontClass @bodyFont}}"
        aria-hidden="true"
      >
        <div class="design-wizard-modal__preview-header">
          {{dIcon "bars"}}
          <span
            class="design-wizard-modal__preview-site-title
              {{fontClass @headingFont 'heading'}}"
          >
            {{this.siteSettings.title}}
          </span>
          {{dIcon "magnifying-glass"}}
        </div>
        <div class="design-wizard-modal__preview-columns">
          <div class="design-wizard-modal__preview-sidebar">
            <span class="design-wizard-modal__preview-new-topic">
              {{i18n "admin_onboarding_banner.design_wizard.preview.new_topic"}}
            </span>
            <span class="design-wizard-modal__preview-nav-item --active">
              {{dIcon "layer-group"}}
              {{i18n "admin_onboarding_banner.design_wizard.preview.topics"}}
            </span>
            <span class="design-wizard-modal__preview-nav-item">
              {{dIcon "far-user"}}
              {{i18n "admin_onboarding_banner.design_wizard.preview.my_posts"}}
            </span>
            <span class="design-wizard-modal__preview-nav-item">
              {{dIcon "far-envelope"}}
              {{i18n
                "admin_onboarding_banner.design_wizard.preview.my_messages"
              }}
            </span>
            <span class="design-wizard-modal__preview-nav-item">
              {{dIcon "wrench"}}
              {{i18n "admin_onboarding_banner.design_wizard.preview.admin"}}
            </span>
            {{#if @userSelectable}}
              <span class="design-wizard-modal__preview-palette-switcher">
                {{dIcon "paintbrush"}}
              </span>
            {{/if}}
          </div>
          <div class="design-wizard-modal__preview-content">
            <h3 class={{fontClass @headingFont "heading"}}>
              {{i18n "admin_onboarding_banner.design_wizard.preview.welcome"}}
            </h3>

            {{#if (eq this.contentVariant "topic-list")}}
              <div class="design-wizard-modal__preview-tabs">
                <span class="--active">{{i18n "filters.latest.title"}}</span>
                <span>{{i18n "filters.hot.title"}}</span>
                <span>{{i18n "filters.categories.title"}}</span>
              </div>
              {{#each this.sampleTopics as |topic|}}
                <div class="design-wizard-modal__preview-topic-row">
                  {{topic}}
                </div>
              {{/each}}
            {{else if (eq this.contentVariant "categories-only")}}
              {{#each this.sampleCategories as |category|}}
                <div class="design-wizard-modal__preview-category-row">
                  <span
                    class="design-wizard-modal__preview-category-badge"
                    style={{badgeStyle category.color}}
                  ></span>
                  {{category.name}}
                </div>
              {{/each}}
            {{else if (eq this.contentVariant "category-boxes")}}
              <div class="design-wizard-modal__preview-category-boxes">
                {{#each this.sampleCategories as |category|}}
                  <div
                    class="design-wizard-modal__preview-category-box"
                    style={{boxStyle category.color}}
                  >
                    {{category.name}}
                  </div>
                {{/each}}
              </div>
            {{else}}
              <div class="design-wizard-modal__preview-split">
                <div>
                  {{#each this.sampleCategories as |category|}}
                    <div class="design-wizard-modal__preview-category-row">
                      <span
                        class="design-wizard-modal__preview-category-badge"
                        style={{badgeStyle category.color}}
                      ></span>
                      {{category.name}}
                    </div>
                  {{/each}}
                </div>
                <div>
                  {{#each this.sampleTopics as |topic|}}
                    <div class="design-wizard-modal__preview-topic-row">
                      {{topic}}
                    </div>
                  {{/each}}
                </div>
              </div>
            {{/if}}
          </div>
        </div>
      </div>
    </div>
  </template>
}
