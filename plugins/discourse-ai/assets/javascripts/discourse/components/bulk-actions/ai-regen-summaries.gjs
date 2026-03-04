import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import { i18n } from "discourse-i18n";
import AiRegenSummariesButtons from "../ai-regen-summaries-buttons";

export default class BulkActionsAiRegenSummaries extends Component {
  @tracked loading = false;

  get topicIds() {
    return this.args.topics.map((t) => t.id);
  }

  @action
  handleLoadingChange(isLoading) {
    this.loading = isLoading;
  }

  <template>
    <div class="ai-bulk-regen-summaries">
      <p class="ai-bulk-regen-summaries__description">
        {{i18n "discourse_ai.summarization.topic.bulk_regen_description"}}
      </p>
      <div class="ai-bulk-regen-summaries__buttons">
        <AiRegenSummariesButtons
          @topicIds={{this.topicIds}}
          @disabled={{this.loading}}
          @onLoadingChange={{this.handleLoadingChange}}
          @onSuccess={{@afterBulkAction}}
        />
      </div>
    </div>
  </template>
}
