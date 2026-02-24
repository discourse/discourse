import Component from "@glimmer/component";
import { concat, fn } from "@ember/helper";
import { action } from "@ember/object";
import { service } from "@ember/service";
import DButton from "discourse/components/d-button";
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
  cancel() {
    this.args.closeModal();
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
      @closeModal={{this.cancel}}
    >
      <:body>
        <div class="predefined-topic-options-modal__list">
          {{#each this.icebreakerTopics as |topic|}}
            <div class="predefined-topic-options-modal__card">
              <div class="predefined-topic-options-modal__content">
                <div class="predefined-topic-options-modal__header">
                  <h4 class="predefined-topic-options-modal__title">
                    {{i18n
                      (concat
                        "admin_onboarding_banner.start_posting.icebreakers."
                        topic
                        ".title"
                      )
                    }}
                  </h4>
                  <DButton
                    @icon="far-pen-to-square"
                    @action={{fn this.handleSelectTopic topic}}
                    class="predefined-topic-options-modal__select-btn btn-primary"
                  />
                </div>
                <p class="predefined-topic-options-modal__body">
                  {{i18n
                    (concat
                      "admin_onboarding_banner.start_posting.icebreakers."
                      topic
                      ".body"
                    )
                  }}
                </p>
              </div>
            </div>
          {{/each}}
        </div>
      </:body>
      <:footer>
        <DButton
          @label="cancel"
          @action={{this.cancel}}
          class="predefined-topic-options-modal__cancel-button btn-transparent"
        />
      </:footer>
    </DModal>
  </template>
}
