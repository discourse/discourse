import Component from "@glimmer/component";
import { concat, fn } from "@ember/helper";
import { action } from "@ember/object";
import DButton from "discourse/components/d-button";
import DModal from "discourse/components/d-modal";
import { i18n } from "discourse-i18n";

export default class PredefinedTopicOptions extends Component {
  @action
  handleBack() {
    this.args.closeModal();
    this.args.model.onBack();
  }

  @action
  handleSelectTopic(topic) {
    this.args.closeModal();
    this.args.model.onSelectTopic(topic);
  }

  <template>
    <DModal
      class="predefined-topic-options-modal"
      @title={{i18n "admin_onboarding_banner.start_posting.predefined_topics"}}
      @closeModal={{this.handleBack}}
    >
      <:body>
        <div class="predefined-topic-options-modal__list">
          {{#each @model.topics as |topic|}}
            <div class="predefined-topic-options-modal__card">
              <div class="predefined-topic-options-modal__content">
                <h4 class="predefined-topic-options-modal__title">
                  {{i18n
                    (concat
                      "admin_onboarding_banner.start_posting.icebreakers."
                      topic
                      ".title"
                    )
                  }}
                </h4>
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
              <DButton
                @label="admin_onboarding_banner.start_posting.select_topic"
                @action={{fn this.handleSelectTopic topic}}
                class="predefined-topic-options-modal__select-btn btn-primary"
              />
            </div>
          {{/each}}
        </div>
      </:body>
      <:footer>
        <DButton
          @label="admin_onboarding_banner.start_posting.back"
          @action={{this.handleBack}}
          class="predefined-topic-options-modal__back-button btn-transparent"
        />
      </:footer>
    </DModal>
  </template>
}
