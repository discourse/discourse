import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import { service } from "@ember/service";
import DButton from "discourse/components/d-button";
import DModal from "discourse/components/d-modal";
import { ajax } from "discourse/lib/ajax";
import { i18n } from "discourse-i18n";

export default class AiRegenSummariesModal extends Component {
  @service siteSettings;
  @service toasts;

  @tracked loading = false;

  get showGistOption() {
    return this.siteSettings.ai_summary_gists_enabled;
  }

  get topicId() {
    return this.args.model.topic.id;
  }

  @action
  async regenerateGists() {
    this.loading = true;

    try {
      await ajax("/discourse-ai/summarization/regen_gist", {
        type: "PUT",
        data: { topic_id: this.topicId },
      });

      this.toasts.success({
        duration: "short",
        data: {
          message: i18n("discourse_ai.summarization.topic.regenerate_success", {
            count: 1,
          }),
        },
      });

      this.args.closeModal();
    } catch {
      this.toasts.error({
        duration: "short",
        data: {
          message: i18n("discourse_ai.summarization.topic.regenerate_error", {
            count: 1,
          }),
        },
      });
    } finally {
      this.loading = false;
    }
  }

  @action
  async regenerateSummaries() {
    this.loading = true;

    try {
      await ajax("/discourse-ai/summarization/regen_summary", {
        type: "PUT",
        data: { topic_id: this.topicId },
      });

      this.toasts.success({
        duration: "short",
        data: {
          message: i18n(
            "discourse_ai.summarization.topic.regenerate_topic_summary_success",
            { count: 1 }
          ),
        },
      });

      this.args.closeModal();
    } catch {
      this.toasts.error({
        duration: "short",
        data: {
          message: i18n(
            "discourse_ai.summarization.topic.regenerate_topic_summary_error",
            { count: 1 }
          ),
        },
      });
    } finally {
      this.loading = false;
    }
  }

  <template>
    <DModal
      @title={{i18n "discourse_ai.summarization.topic.regenerate_ai_summaries"}}
      @closeModal={{@closeModal}}
      class="ai-regen-summaries-modal"
    >
      <:body>
        <p class="ai-regen-summaries-modal__description">
          {{i18n "discourse_ai.summarization.topic.regen_modal_description"}}
        </p>
        <div class="ai-regen-summaries-modal__buttons">
          {{#if this.showGistOption}}
            <DButton
              @label="discourse_ai.summarization.topic.regenerate_gists_option"
              @icon="arrows-rotate"
              @action={{this.regenerateGists}}
              @disabled={{this.loading}}
              class="btn-primary ai-regen-gists-btn"
            />
          {{/if}}
          <DButton
            @label="discourse_ai.summarization.topic.regenerate_summaries_option"
            @icon="arrows-rotate"
            @action={{this.regenerateSummaries}}
            @disabled={{this.loading}}
            class="btn-primary ai-regen-summaries-btn"
          />
        </div>
      </:body>
    </DModal>
  </template>
}
