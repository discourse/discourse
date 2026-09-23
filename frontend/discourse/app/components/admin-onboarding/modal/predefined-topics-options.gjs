import Component from "@glimmer/component";
import { concat, fn } from "@ember/helper";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { service } from "@ember/service";
import Category from "discourse/models/category";
import DModal from "discourse/ui-kit/d-modal";
import dCategoryBadge from "discourse/ui-kit/helpers/d-category-badge";
import { i18n } from "discourse-i18n";

export default class PredefinedTopicOptions extends Component {
  @service composer;
  @service siteSettings;

  get topics() {
    const staff = Category.findById(this.siteSettings.staff_category_id);
    const general = Category.findById(this.siteSettings.general_category_id);

    return [
      { key: "plan_categories", category: staff },
      { key: "plan_invites", category: staff },
      { key: "introduce_yourself", category: general },
      { key: "write_your_own", category: general },
    ].map((topic) => ({
      ...topic,
      disabled: !topic.category?.canCreateTopic,
    }));
  }

  @action
  handleSelectTopic(topic) {
    if (topic.disabled) {
      return;
    }

    this.args.closeModal();
    const custom = topic.key === "write_your_own";

    this.composer.openNewTopic({
      title: custom
        ? ""
        : i18n(
            `admin_onboarding_banner.start_posting.icebreakers.${topic.key}.title`
          ),
      body: custom
        ? ""
        : i18n(
            `admin_onboarding_banner.start_posting.icebreakers.${topic.key}.body`
          ),
      category: topic.category,
      // Draft metadata follows this composer, not the last card clicked. It
      // survives draft restoration and is discarded with an abandoned topic.
      adminOnboardingTopicOption: topic.key,
    });
  }

  <template>
    <DModal
      class="predefined-topic-options-modal"
      @closeModal={{@closeModal}}
      @subtitle={{i18n
        "admin_onboarding_banner.start_posting.predefined_topics_subtitle"
      }}
      @title={{i18n "admin_onboarding_banner.start_posting.predefined_topics"}}
    >
      <:body>
        <div class="predefined-topic-options-modal__list">
          {{#each this.topics as |topic|}}
            <button
              class="predefined-topic-options-modal__card"
              data-topic-option={{topic.key}}
              disabled={{topic.disabled}}
              title={{if
                topic.disabled
                (i18n
                  "admin_onboarding_banner.start_posting.category_unavailable"
                )
              }}
              type="button"
              {{on "click" (fn this.handleSelectTopic topic)}}
            >
              <span class="predefined-topic-options-modal__heading">
                <span class="predefined-topic-options-modal__title">
                  {{i18n
                    (concat
                      "admin_onboarding_banner.start_posting.icebreakers."
                      topic.key
                      ".title"
                    )
                  }}
                </span>
                {{#if topic.category}}
                  {{dCategoryBadge topic.category}}
                {{/if}}
              </span>
              <p class="predefined-topic-options-modal__body">
                {{i18n
                  (concat
                    "admin_onboarding_banner.start_posting.icebreakers."
                    topic.key
                    ".body"
                  )
                }}
              </p>
            </button>
          {{/each}}
        </div>
      </:body>
    </DModal>
  </template>
}
