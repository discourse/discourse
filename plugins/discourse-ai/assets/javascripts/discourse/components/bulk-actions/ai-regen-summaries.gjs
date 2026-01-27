import Component from "@glimmer/component";
import { i18n } from "discourse-i18n";
import AiRegenSummariesButtons from "../ai-regen-summaries-buttons";

export default class BulkActionsAiRegenSummaries extends Component {
  get topicIds() {
    return this.args.topics.map((t) => t.id);
  }

  <template>
    <div class="ai-bulk-regen-summaries">
      <p class="ai-bulk-regen-summaries__description">
        {{i18n "discourse_ai.summarization.topic.bulk_regen_description"}}
      </p>
      <div class="ai-bulk-regen-summaries__buttons">
        <AiRegenSummariesButtons
          @topicIds={{this.topicIds}}
          @onSuccess={{@afterBulkAction}}
        />
      </div>
    </div>
  </template>
}
