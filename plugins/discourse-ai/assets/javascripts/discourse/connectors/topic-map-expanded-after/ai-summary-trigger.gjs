import Component from "@glimmer/component";
import { action } from "@ember/object";
import { service } from "@ember/service";
import DButton from "discourse/components/d-button";
import AiSummaryModal from "../../components/modal/ai-summary-modal";

export default class AiSummaryTrigger extends Component {
  @service modal;

  get isAiConversation() {
    return this.args.outletArgs.topic.is_bot_pm;
  }

  @action
  openAiSummaryModal() {
    this.modal.show(AiSummaryModal, {
      model: {
        topic: this.args.outletArgs.topic,
        postStream: this.args.outletArgs.postStream,
      },
    });
  }

  <template>
    {{#unless this.isAiConversation}}
      {{#if @outletArgs.topic.summarizable}}
        <section class="topic-map__additional-contents toggle-summary">
          <DButton
            @label="summary.buttons.generate"
            @icon="discourse-sparkles"
            @action={{this.openAiSummaryModal}}
            class="btn-default ai-summarization-button"
          />
        </section>
      {{/if}}
    {{/unless}}
  </template>
}
