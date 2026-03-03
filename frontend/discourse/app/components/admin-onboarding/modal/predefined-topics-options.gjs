import Component from "@glimmer/component";
import { concat, fn } from "@ember/helper";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { service } from "@ember/service";
import DModal from "discourse/components/d-modal";
import { i18n } from "discourse-i18n";

export default class PredefinedTopicOptions extends Component {
  @service composer;

  icebreakerTopics = [
    "fun_facts",
    "coolest_thing_you_have_seen_today",
    "introduce_yourself",
    "what_is_your_favorite_food",
  ];

  openTopic(topicKey) {
    this.composer.openNewTopic({
      title: i18n(
        `admin_onboarding_banner.start_posting.icebreakers.${topicKey}.title`
      ),
      body: i18n(
        `admin_onboarding_banner.start_posting.icebreakers.${topicKey}.body`
      ),
    });
  }

  @action
  handleSelectTopic(topic) {
    this.args.closeModal();
    this.openTopic(topic);
  }

  <template>
    <DModal
      class="predefined-topic-options-modal"
      @title={{i18n "admin_onboarding_banner.start_posting.predefined_topics"}}
      @subtitle={{i18n
        "admin_onboarding_banner.start_posting.predefined_topics_subtitle"
      }}
      @closeModal={{@closeModal}}
    >
      <:body>
        <div class="predefined-topic-options-modal__list">
          {{#each this.icebreakerTopics as |topic|}}
            <button
              type="button"
              class="predefined-topic-options-modal__card"
              {{on "click" (fn this.handleSelectTopic topic)}}
            >
              <span class="predefined-topic-options-modal__title">
                {{i18n
                  (concat
                    "admin_onboarding_banner.start_posting.icebreakers."
                    topic
                    ".title"
                  )
                }}
              </span>
              <p class="predefined-topic-options-modal__body">
                {{i18n
                  (concat
                    "admin_onboarding_banner.start_posting.icebreakers."
                    topic
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
