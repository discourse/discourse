import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import DModal from "discourse/ui-kit/d-modal";
import { i18n } from "discourse-i18n";
import AiRegenSummariesButtons from "../ai-regen-summaries-buttons";

export default class AiRegenSummariesModal extends Component {
  @tracked loading = false;

  get topicIds() {
    return [this.args.model.topic.id];
  }

  @action
  handleLoadingChange(isLoading) {
    this.loading = isLoading;
  }

  @action
  handleSuccess() {
    this.args.closeModal();
  }

  <template>
    <DModal
      class="ai-regen-summaries-modal"
      @closeModal={{@closeModal}}
      @title={{i18n "discourse_ai.summarization.topic.regenerate_ai_summaries"}}
    >
      <:body>
        <p class="ai-regen-summaries-modal__description">
          {{i18n "discourse_ai.summarization.topic.regen_modal_description"}}
        </p>
        <div class="ai-regen-summaries-modal__buttons">
          <AiRegenSummariesButtons
            @disabled={{this.loading}}
            @onLoadingChange={{this.handleLoadingChange}}
            @onSuccess={{this.handleSuccess}}
            @topicIds={{this.topicIds}}
          />
        </div>
      </:body>
    </DModal>
  </template>
}
