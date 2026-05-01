import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import didInsert from "@ember/render-modifiers/modifiers/did-insert";
import willDestroy from "@ember/render-modifiers/modifiers/will-destroy";
import { service } from "@ember/service";
import DButton from "discourse/components/d-button";
import DockedComposer from "discourse/components/docked-composer";
import concatClass from "discourse/helpers/concat-class";
import icon from "discourse/helpers/d-icon";
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

  @tracked showToolbar = false;
  @tracked hasContentBelow = false;

  #resizeObserver = null;

  #checkScroll = () => {
    const threshold = 100;
    this.hasContentBelow =
      document.documentElement.scrollHeight -
        window.scrollY -
        window.innerHeight >
      threshold;
  };

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

  get composerClass() {
    const classes = ["ai-bot-docked-composer"];
    if (!this.showToolbar) {
      classes.push("docked-composer--toolbar-hidden");
    }
    if (!this.hasContentBelow) {
      classes.push("docked-composer--at-bottom");
    }
    return classes.join(" ");
  }

  get showScrollIndicator() {
    return this.isBotPm && this.hasContentBelow;
  }

  get maxResizeOffset() {
    return Math.floor(window.innerHeight / 2);
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
  toggleToolbar() {
    this.showToolbar = !this.showToolbar;
  }

  @action
  async onStopStreaming() {
    if (!this.topicId) {
      return;
    }
    await this.aiBotStreamingState.stopStreaming(this.topicId);
  }

  @action
  setupScrollListener() {
    window.addEventListener("scroll", this.#checkScroll, { passive: true });
    this.#resizeObserver = new ResizeObserver(this.#checkScroll);
    this.#resizeObserver.observe(document.body);
    this.#checkScroll();
  }

  @action
  teardownScrollListener() {
    window.removeEventListener("scroll", this.#checkScroll);
    this.#resizeObserver?.disconnect();
    this.#resizeObserver = null;
  }

  @action
  scrollToBottom() {
    window.scrollTo({
      top: document.documentElement.scrollHeight,
      behavior: "smooth",
    });
  }

  <template>
    <DockedComposer
      @show={{this.isBotPm}}
      @class={{this.composerClass}}
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
      @maxResizeOffset={{this.maxResizeOffset}}
      {{didInsert this.setupScrollListener}}
      {{willDestroy this.teardownScrollListener}}
    >
      <:submit as |ctx|>
        <DButton
          @icon={{if this.showToolbar "xmark" "plus"}}
          @action={{this.toggleToolbar}}
          @title={{if
            this.showToolbar
            "discourse_ai.ai_bot.conversations.hide_toolbar"
            "discourse_ai.ai_bot.conversations.show_toolbar"
          }}
          class="docked-composer__submit-btn ai-bot-docked-composer__toolbar-toggle"
        />
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
        {{#if this.showScrollIndicator}}
          <button
            type="button"
            aria-label={{if
              this.isStreaming
              (i18n "discourse_ai.ai_bot.conversations.streaming_below")
              (i18n "discourse_ai.ai_bot.conversations.scroll_to_bottom")
            }}
            class={{concatClass
              "ai-bot-scroll-indicator"
              (if this.isStreaming "ai-bot-scroll-indicator--streaming")
            }}
            {{on "click" this.scrollToBottom}}
          >
            {{#if this.isStreaming}}
              <span class="ai-bot-scroll-indicator__dots">
                <span class="ai-bot-scroll-indicator__dot"></span><span
                  class="ai-bot-scroll-indicator__dot"
                ></span><span class="ai-bot-scroll-indicator__dot"></span>
              </span>
            {{else}}
              {{icon "chevron-down"}}
            {{/if}}
          </button>
        {{/if}}
        <p class="ai-bot-docked-composer__disclaimer">
          {{i18n "discourse_ai.ai_bot.conversations.disclaimer"}}
        </p>
      </:default>
    </DockedComposer>
  </template>
}
