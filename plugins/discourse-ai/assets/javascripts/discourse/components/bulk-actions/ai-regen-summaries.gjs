import Component from "@glimmer/component";
import { action } from "@ember/object";
import { service } from "@ember/service";
import DButton from "discourse/components/d-button";
import { ajax } from "discourse/lib/ajax";
import { i18n } from "discourse-i18n";

export default class BulkActionsAiRegenSummaries extends Component {
  @service siteSettings;
  @service toasts;

  get showGistOption() {
    return this.siteSettings.ai_summary_gists_enabled;
  }

  get topicIds() {
    return this.args.topics.map((t) => t.id);
  }

  @action
  async regenerateGists() {
    try {
      await ajax("/discourse-ai/summarization/regen_gist", {
        type: "PUT",
        data: { topic_ids: this.topicIds },
      });

      this.toasts.success({
        duration: "short",
        data: {
          message: i18n("discourse_ai.summarization.topic.regenerate_success", {
            count: this.topicIds.length,
          }),
        },
      });

      this.args.afterBulkAction?.();
    } catch {
      this.toasts.error({
        duration: "short",
        data: {
          message: i18n("discourse_ai.summarization.topic.regenerate_error", {
            count: this.topicIds.length,
          }),
        },
      });
    }
  }

  @action
  async regenerateSummaries() {
    try {
      await ajax("/discourse-ai/summarization/regen_summary", {
        type: "PUT",
        data: { topic_ids: this.topicIds },
      });

      this.toasts.success({
        duration: "short",
        data: {
          message: i18n(
            "discourse_ai.summarization.topic.regenerate_topic_summary_success",
            { count: this.topicIds.length }
          ),
        },
      });

      this.args.afterBulkAction?.();
    } catch {
      this.toasts.error({
        duration: "short",
        data: {
          message: i18n(
            "discourse_ai.summarization.topic.regenerate_topic_summary_error",
            { count: this.topicIds.length }
          ),
        },
      });
    }
  }

  <template>
    <div class="ai-bulk-regen-summaries">
      <p class="ai-bulk-regen-summaries__description">
        {{i18n "discourse_ai.summarization.topic.bulk_regen_description"}}
      </p>
      <div class="ai-bulk-regen-summaries__buttons">
        {{#if this.showGistOption}}
          <DButton
            @label="discourse_ai.summarization.topic.regenerate_gists_option"
            @icon="arrows-rotate"
            @action={{this.regenerateGists}}
            class="btn-primary ai-regen-gists-btn"
          />
        {{/if}}
        <DButton
          @label="discourse_ai.summarization.topic.regenerate_summaries_option"
          @icon="arrows-rotate"
          @action={{this.regenerateSummaries}}
          class="btn-primary ai-regen-summaries-btn"
        />
      </div>
    </div>
  </template>
}
