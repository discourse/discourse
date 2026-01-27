import Component from "@glimmer/component";
import { action } from "@ember/object";
import { service } from "@ember/service";
import DButton from "discourse/components/d-button";
import { ajax } from "discourse/lib/ajax";
import { i18n } from "discourse-i18n";

export default class AiRegenSummariesButtons extends Component {
  @service siteSettings;
  @service toasts;

  get showGistOption() {
    return this.siteSettings.ai_summary_gists_enabled;
  }

  get topicIds() {
    return this.args.topicIds;
  }

  get count() {
    return this.topicIds.length;
  }

  get dataPayload() {
    return this.count === 1
      ? { topic_id: this.topicIds[0] }
      : { topic_ids: this.topicIds };
  }

  @action
  async regenerateGists() {
    this.args.onLoadingChange?.(true);

    try {
      await ajax("/discourse-ai/summarization/regen_gist", {
        type: "PUT",
        data: this.dataPayload,
      });

      this.toasts.success({
        data: {
          message: i18n("discourse_ai.summarization.topic.regenerate_success", {
            count: this.count,
          }),
        },
      });

      this.args.onSuccess?.();
    } catch {
      this.toasts.error({
        data: {
          message: i18n("discourse_ai.summarization.topic.regenerate_error", {
            count: this.count,
          }),
        },
      });
    } finally {
      this.args.onLoadingChange?.(false);
    }
  }

  @action
  async regenerateSummaries() {
    this.args.onLoadingChange?.(true);

    try {
      await ajax("/discourse-ai/summarization/regen_summary", {
        type: "PUT",
        data: this.dataPayload,
      });

      this.toasts.success({
        data: {
          message: i18n(
            "discourse_ai.summarization.topic.regenerate_topic_summary_success",
            { count: this.count }
          ),
        },
      });

      this.args.onSuccess?.();
    } catch {
      this.toasts.error({
        data: {
          message: i18n(
            "discourse_ai.summarization.topic.regenerate_topic_summary_error",
            { count: this.count }
          ),
        },
      });
    } finally {
      this.args.onLoadingChange?.(false);
    }
  }

  <template>
    {{#if this.showGistOption}}
      <DButton
        @label="discourse_ai.summarization.topic.regenerate_gists_option"
        @icon="arrows-rotate"
        @action={{this.regenerateGists}}
        @disabled={{@disabled}}
        class="btn-primary ai-regen-gists-btn"
      />
    {{/if}}
    <DButton
      @label="discourse_ai.summarization.topic.regenerate_summaries_option"
      @icon="arrows-rotate"
      @action={{this.regenerateSummaries}}
      @disabled={{@disabled}}
      class="btn-primary ai-regen-summaries-btn"
    />
  </template>
}
