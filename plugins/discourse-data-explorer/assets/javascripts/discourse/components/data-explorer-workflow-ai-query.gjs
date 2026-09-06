import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import dIcon from "discourse/ui-kit/helpers/d-icon";
import { i18n } from "discourse-i18n";
import { subscribeToAiGeneration } from "discourse/plugins/discourse-data-explorer/discourse/lib/ai-generation";
import { dataExplorerAiQueriesEnabled } from "discourse/plugins/discourse-data-explorer/discourse/lib/ai-query-availability";
import QueryAiPrompt from "./query-ai-prompt";

export default class DataExplorerWorkflowAiQuery extends Component {
  @service messageBus;
  @service siteSettings;
  @service toasts;

  @tracked prompt = "";
  @tracked generating = false;

  #teardownAiGeneration = null;

  willDestroy() {
    super.willDestroy(...arguments);
    this.#teardownAiGeneration?.();
  }

  get shouldRender() {
    return (
      dataExplorerAiQueriesEnabled(this.siteSettings) &&
      this.args.node?.type === "action:sql" &&
      this.args.fieldName === "query" &&
      this.args.nodeParameters?.operation === "raw"
    );
  }

  get sql() {
    return this.args.field.value?.toString() || "";
  }

  get actionLabel() {
    return this.sql.trim() ? "explorer.ai.regenerate" : "explorer.ai.generate";
  }

  get placeholder() {
    return this.sql.trim()
      ? i18n("explorer.ai.regenerate_placeholder")
      : i18n("explorer.ai.description_placeholder");
  }

  get generateDisabled() {
    return this.disabled || !this.prompt.trim();
  }

  get disabled() {
    return this.generating || this.args.field.disabled;
  }

  @action
  updatePrompt(event) {
    this.prompt = event.target.value;
  }

  @action
  async generate() {
    if (this.generateDisabled) {
      return;
    }

    this.generating = true;

    try {
      const { generation_id: generationId } = await ajax(
        "/admin/plugins/discourse-data-explorer/queries/generate.json",
        {
          type: "POST",
          data: {
            ai_description: this.prompt.trim(),
            existing_sql: this.sql.trim() || undefined,
          },
        }
      );

      if (this.isDestroying || this.isDestroyed) {
        return;
      }

      this.#teardownAiGeneration = subscribeToAiGeneration({
        messageBus: this.messageBus,
        generationId,
        onComplete: ({ sql }) => {
          this.args.field.set(sql);
          this.generating = false;
        },
        onError: ({ error }) => {
          this.#showGenerationError(
            error || i18n("explorer.ai.generation_error")
          );
        },
        onTimeout: () => {
          this.#showGenerationError(i18n("explorer.ai.generation_timeout"));
        },
      });
    } catch (error) {
      if (this.isDestroying || this.isDestroyed) {
        return;
      }

      this.generating = false;
      popupAjaxError(error);
    }
  }

  #showGenerationError(message) {
    this.generating = false;
    this.toasts.error({ data: { message } });
  }

  <template>
    {{#if this.shouldRender}}
      <section
        class="data-explorer-workflow-ai-query"
        aria-labelledby="data-explorer-workflow-ai-query-title"
      >
        <header class="data-explorer-workflow-ai-query__header">
          <span class="data-explorer-workflow-ai-query__icon">
            {{dIcon "discourse-sparkles"}}
          </span>
          <h3
            id="data-explorer-workflow-ai-query-title"
            class="data-explorer-workflow-ai-query__title"
          >
            {{i18n "explorer.ai.workflow_title"}}
          </h3>
        </header>
        <QueryAiPrompt
          @value={{this.prompt}}
          @onChange={{this.updatePrompt}}
          @onRegenerate={{this.generate}}
          @regenerateDisabled={{this.generateDisabled}}
          @generating={{this.generating}}
          @disabled={{this.disabled}}
          @actionLabel={{this.actionLabel}}
          @actionClass="btn-primary"
          @placeholder={{this.placeholder}}
          class="data-explorer-workflow-ai-query__prompt"
        />
      </section>
    {{/if}}
  </template>
}
