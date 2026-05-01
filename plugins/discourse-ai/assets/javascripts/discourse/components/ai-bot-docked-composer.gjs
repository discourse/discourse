import Component from "@glimmer/component";
import { action } from "@ember/object";
import { service } from "@ember/service";
import DButton from "discourse/components/d-button";
import DockedComposer from "discourse/components/docked-composer";
import { i18n } from "discourse-i18n";

const DRAFT_KEY_PREFIX = "ai-bot-docked-draft-";

/**
 * Thin AI-bot-specific wrapper around the generic `DockedComposer`.
 *
 * Rendered in the `topic-area-bottom` outlet, so it receives the topic
 * model via `@outletArgs.model`. Gates rendering on the topic being an
 * AI bot PM, wires up the bot-specific submit and streaming services,
 * and overrides the base composer's submit button via the `<:submit>`
 * block to swap between a paper-plane send icon and a pause "stop
 * generating" icon while the bot is replying.
 */
export default class AiBotDockedComposer extends Component {
  @service aiBotDockedSubmit;
  @service aiBotStreamingState;
  @service siteSettings;

  get topic() {
    return this.args.outletArgs?.model ?? null;
  }

  get isBotPm() {
    return this.topic?.is_bot_pm === true;
  }

  get topicId() {
    return this.topic?.id;
  }

  get draftKey() {
    // Falsy topicId means the outlet is rendering without a model
    // (shouldn't happen on topic routes, but guard anyway so we don't
    // stamp `ai-bot-docked-draft-undefined` into the key-value store).
    if (!this.topicId) {
      return null;
    }
    return `${DRAFT_KEY_PREFIX}${this.topicId}`;
  }

  get isStreaming() {
    return this.aiBotStreamingState.isStreamingForTopic(this.topicId);
  }

  get minLength() {
    return this.siteSettings.min_personal_message_post_length ?? 1;
  }

  @action
  async onSubmit({ raw, uploads, inProgressUploadsCount }) {
    return this.aiBotDockedSubmit.submitReply({
      topicId: this.topicId,
      raw,
      uploads,
      inProgressUploadsCount,
    });
  }

  @action
  async onStopStreaming() {
    if (!this.topicId) {
      return;
    }
    await this.aiBotStreamingState.stopStreaming(this.topicId);
  }

  <template>
    <DockedComposer
      @show={{this.isBotPm}}
      @class="ai-bot-docked-composer"
      @bodyClassName="has-ai-bot-docked-composer"
      @topicId={{this.topicId}}
      @draftKey={{this.draftKey}}
      @uploaderId="ai-bot-docked-file-uploader"
      @uploadType="ai-bot-conversation"
      @minLength={{this.minLength}}
      @placeholder={{i18n "discourse_ai.ai_bot.conversations.placeholder"}}
      @submitTitle={{i18n "discourse_ai.ai_bot.conversations.header"}}
      @uploadTitle="discourse_ai.ai_bot.conversations.upload_files"
      @onSubmit={{this.onSubmit}}
      @isSubmitting={{this.aiBotDockedSubmit.loading}}
      @disabled={{this.isStreaming}}
      @resizable={{true}}
    >
      <:submit as |ctx|>
        {{#if this.isStreaming}}
          <DButton
            @icon="pause"
            @action={{this.onStopStreaming}}
            @title="discourse_ai.ai_bot.cancel_streaming"
            class="docked-composer__submit-btn"
          />
        {{else}}
          <DButton
            @icon="paper-plane"
            @action={{ctx.submit}}
            @disabled={{ctx.disabled}}
            @isLoading={{ctx.isSubmitting}}
            @title="discourse_ai.ai_bot.conversations.header"
            class="docked-composer__submit-btn"
          />
        {{/if}}
      </:submit>
      <:default>
        <p class="ai-bot-docked-composer__disclaimer">
          {{i18n "discourse_ai.ai_bot.conversations.disclaimer"}}
        </p>
      </:default>
    </DockedComposer>
  </template>
}
