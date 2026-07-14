import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import didInsert from "@ember/render-modifiers/modifiers/did-insert";
import willDestroy from "@ember/render-modifiers/modifiers/will-destroy";
import { schedule } from "@ember/runloop";
import { service } from "@ember/service";
import DockedComposer from "discourse/components/docked-composer";
import { ajax } from "discourse/lib/ajax";
import { buildQuote } from "discourse/lib/quote";
import DButton from "discourse/ui-kit/d-button";
import dAvatar from "discourse/ui-kit/helpers/d-avatar";
import dConcatClass from "discourse/ui-kit/helpers/d-concat-class";
import dIcon from "discourse/ui-kit/helpers/d-icon";
import { i18n } from "discourse-i18n";
import { isGPTBot } from "../lib/ai-bot-helper";

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
  @service appEvents;
  @service aiBotDockedSubmit;
  @service aiBotStreamingState;
  @service siteSettings;
  @service store;

  @tracked showToolbar = false;
  @tracked hasContentBelow = false;
  @tracked editingPost = null;
  @tracked pendingBotReply = false;

  #composerApi = null;
  #resizeObserver = null;
  #keyboardOpen = false;
  #composerEl = null;
  #placeholderEl = null;
  #mutationObserver = null;
  #streamEndObserver = null;
  #pendingBotReplyTimeout = null;

  #checkScroll = () => {
    // Must run before any early return so the value is always current.
    if (this.#composerEl) {
      document.documentElement.style.setProperty(
        "--ai-docked-composer-height",
        `${this.#composerEl.offsetHeight}px`
      );
    }

    const scrollH = document.documentElement.scrollHeight;
    const totalScrollable = scrollH - window.innerHeight;

    if (totalScrollable <= 0) {
      if (this.hasContentBelow) {
        this.hasContentBelow = false;
      }
      return;
    }

    const distFromBottom = scrollH - window.scrollY - window.innerHeight;
    const hasContentBelow = distFromBottom > 100;
    if (hasContentBelow !== this.hasContentBelow) {
      this.hasContentBelow = hasContentBelow;
    }
  };

  #alignWithPost = () => {
    const composerEl = this.#composerEl;
    if (!composerEl) {
      return;
    }
    const postContents = document.querySelector(".topic-post .contents");
    const inner = composerEl.querySelector(".docked-composer__inner");
    if (postContents && inner) {
      const offset = Math.max(
        0,
        Math.round(
          postContents.getBoundingClientRect().left -
            inner.getBoundingClientRect().left
        )
      );
      composerEl.style.setProperty(
        "--docked-composer-content-offset",
        `${offset}px`
      );
      this.#placeholderEl?.style.setProperty(
        "--docked-composer-content-offset",
        `${offset}px`
      );
    } else {
      composerEl.style.removeProperty("--docked-composer-content-offset");
      this.#placeholderEl?.style.removeProperty(
        "--docked-composer-content-offset"
      );
    }
  };

  #onViewportChange = () => {
    const composerEl = this.#composerEl;
    if (!composerEl) {
      return;
    }

    composerEl.style.setProperty(
      "--docked-composer-max-resize-offset",
      `${this.maxResizeOffset}px`
    );
    this.#alignWithPost();

    if (!window.visualViewport) {
      return;
    }
    const keyboardOffset = window.innerHeight - window.visualViewport.height;
    if (keyboardOffset > 100) {
      if (!this.#keyboardOpen) {
        this.#keyboardOpen = true;
        composerEl.classList.add("docked-composer--keyboard-open");
      }
      const top =
        window.visualViewport.offsetTop +
        window.visualViewport.height -
        composerEl.offsetHeight;
      composerEl.style.top = `${top}px`;
    } else if (this.#keyboardOpen) {
      this.#keyboardOpen = false;
      composerEl.classList.remove("docked-composer--keyboard-open");
      composerEl.style.top = "";
    }
  };

  get topic() {
    return this.args.outletArgs?.model ?? null;
  }

  get isBotPm() {
    return (
      this.siteSettings.ai_bot_enable_docked_composer &&
      this.topic?.is_bot_pm === true
    );
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

  get botUser() {
    return this.topic?.details?.allowed_users?.find(isGPTBot) ?? null;
  }

  get showPlaceholder() {
    return this.isBotPm && this.pendingBotReply && !!this.botUser;
  }

  @action
  toggleToolbar() {
    this.showToolbar = !this.showToolbar;
  }

  #swapPlaceholderForPost(postId) {
    // data-post-id is the database ID; the DOM id uses post_number instead.
    const postEl = document.querySelector(`[data-post-id="${postId}"]`);
    if (!postEl) {
      return false;
    }
    postEl.classList.add("ai-bot-streaming-placeholder");
    if (this.#placeholderEl) {
      this.#placeholderEl.style.display = "none";
      this.#placeholderEl = null;
    }
    this.pendingBotReply = false;
    return true;
  }

  @action
  handleBotReplyStarted({ topicId, postId }) {
    if (topicId !== this.topicId || !postId) {
      return;
    }
    clearTimeout(this.#pendingBotReplyTimeout);
    this.#pendingBotReplyTimeout = null;
    if (this.#swapPlaceholderForPost(postId)) {
      return;
    }
    // MutationObserver fires as a microtask (before paint); rAF would fire
    // one frame later, briefly showing both the placeholder and real post.
    this.#mutationObserver?.disconnect();
    this.#mutationObserver = new MutationObserver(() => {
      if (this.#swapPlaceholderForPost(postId)) {
        this.#mutationObserver?.disconnect();
        this.#mutationObserver = null;
      }
    });
    this.#mutationObserver.observe(
      document.querySelector(".topic-area") ?? document.body,
      { childList: true, subtree: true }
    );
  }

  @action
  handleBotReplyFinished({ topicId, postId }) {
    if (topicId !== this.topicId || !postId) {
      return;
    }
    this.#streamEndObserver?.disconnect();
    this.#streamEndObserver = null;

    const postEl = document.querySelector(`[data-post-id="${postId}"]`);
    if (!postEl) {
      return;
    }

    const release = () => {
      requestAnimationFrame(() => {
        postEl.classList.remove("ai-bot-streaming-placeholder");
      });
    };

    // PostUpdater removes .streaming ~40ms after data.done when morphdom
    // finishes. Releasing min-height before that causes a mid-transition
    // height jump as the natural content height changes under the animation.
    if (!postEl.classList.contains("streaming")) {
      release();
      return;
    }

    this.#streamEndObserver = new MutationObserver(() => {
      if (!postEl.classList.contains("streaming")) {
        this.#streamEndObserver?.disconnect();
        this.#streamEndObserver = null;
        release();
      }
    });
    this.#streamEndObserver.observe(postEl, {
      attributes: true,
      attributeFilter: ["class"],
    });
  }

  @action
  registerPlaceholder(element) {
    this.#placeholderEl = element;
    this.#alignWithPost();
  }

  @action
  async onStopStreaming() {
    if (!this.topicId) {
      return;
    }
    await this.aiBotStreamingState.stopStreaming(this.topicId);
  }

  @action
  registerComposerApi(api) {
    this.#composerApi = api;
  }

  @action
  handleEditPost(event) {
    if (!this.isBotPm) {
      return;
    }
    event.handled = true;
    this.#startEditing(event.post);
  }

  @action
  handleQuotePost(event) {
    if (!this.isBotPm) {
      return;
    }
    event.handled = true;
    const quotedText = buildQuote(event.post, event.buffer, event.opts);
    if (quotedText?.trim()) {
      this.appEvents.trigger("composer:insert-block", quotedText);
    }
  }

  async #startEditing(post) {
    const fullPost = await this.store.find("post", post.id);
    this.editingPost = fullPost;
    this.#composerApi?.setReply(fullPost.raw);
    schedule("afterRender", () => {
      this.#composerEl?.querySelector(".d-editor-input")?.focus();
    });
  }

  @action
  cancelEditing() {
    this.editingPost = null;
    this.#composerApi?.setReply("");
  }

  @action
  async onSubmit({ raw, uploads, inProgressUploadsCount }) {
    if (this.editingPost) {
      return this.#submitEdit(raw);
    }
    const result = await this.aiBotDockedSubmit.submitReply({
      topicId: this.topicId,
      raw,
      uploads,
      inProgressUploadsCount,
    });
    if (result) {
      this.pendingBotReply = true;
      clearTimeout(this.#pendingBotReplyTimeout);
      this.#pendingBotReplyTimeout = setTimeout(() => {
        this.pendingBotReply = false;
      }, 10000);
      schedule("afterRender", () => {
        window.scrollTo({ top: document.documentElement.scrollHeight });
      });
      if (result.post?.post_number) {
        this.appEvents.trigger("discourse-ai:post-submitted", {
          topicId: this.topicId,
          userPostNumber: result.post.post_number,
        });
      }
    }
    return result;
  }

  async #submitEdit(raw) {
    const post = this.editingPost;

    const result = await ajax(`/posts/${post.id}.json`, {
      type: "PUT",
      data: { post: { raw } },
    });

    const topic = this.topic;
    const loadedPost = topic?.postStream?.findLoadedPost(post.id);
    if (loadedPost) {
      loadedPost.setProperties({
        raw: result.post.raw,
        cooked: result.post.cooked,
        version: result.post.version,
        updated_at: result.post.updated_at,
      });
    }

    this.editingPost = null;
    return { ok: true };
  }

  @action
  setupScrollListener(element) {
    this.#composerEl = element;
    window.addEventListener("scroll", this.#checkScroll, { passive: true });
    this.#resizeObserver = new ResizeObserver(this.#checkScroll);
    this.#resizeObserver.observe(document.body);
    this.#resizeObserver.observe(element);
    this.#checkScroll();
    this.#alignWithPost();
    window.visualViewport?.addEventListener("resize", this.#onViewportChange);
    window.visualViewport?.addEventListener("scroll", this.#onViewportChange);
    window.addEventListener("resize", this.#onViewportChange);
    this.appEvents.on("topic:edit-post", this, this.handleEditPost);
    this.appEvents.on("topic:quote-post", this, this.handleQuotePost);
    this.appEvents.on(
      "discourse-ai:bot-reply-started",
      this,
      this.handleBotReplyStarted
    );
    this.appEvents.on(
      "discourse-ai:bot-reply-finished",
      this,
      this.handleBotReplyFinished
    );
  }

  @action
  teardownScrollListener() {
    this.#composerEl = null;
    window.removeEventListener("scroll", this.#checkScroll);
    this.#resizeObserver?.disconnect();
    this.#resizeObserver = null;
    window.visualViewport?.removeEventListener(
      "resize",
      this.#onViewportChange
    );
    window.visualViewport?.removeEventListener(
      "scroll",
      this.#onViewportChange
    );
    window.removeEventListener("resize", this.#onViewportChange);
    document.documentElement.style.removeProperty(
      "--ai-docked-composer-height"
    );
    this.appEvents.off("topic:edit-post", this, this.handleEditPost);
    this.appEvents.off("topic:quote-post", this, this.handleQuotePost);
    this.appEvents.off(
      "discourse-ai:bot-reply-started",
      this,
      this.handleBotReplyStarted
    );
    this.appEvents.off(
      "discourse-ai:bot-reply-finished",
      this,
      this.handleBotReplyFinished
    );
    this.#mutationObserver?.disconnect();
    this.#mutationObserver = null;
    this.#streamEndObserver?.disconnect();
    this.#streamEndObserver = null;
    this.#placeholderEl = null;
    clearTimeout(this.#pendingBotReplyTimeout);
    this.#pendingBotReplyTimeout = null;
  }

  @action
  scrollToBottom() {
    window.scrollTo({
      top: document.documentElement.scrollHeight,
      behavior: "smooth",
    });
  }

  <template>
    {{#if this.showPlaceholder}}
      <div
        class="ai-bot-reply-placeholder"
        {{didInsert this.registerPlaceholder}}
      >
        <div class="ai-bot-reply-placeholder__row">
          <div class="ai-bot-reply-placeholder__avatar">
            {{dAvatar this.botUser imageSize="large"}}
          </div>
          <div class="ai-bot-reply-placeholder__body">
            <span
              class="ai-bot-reply-placeholder__username"
            >{{this.botUser.username}}</span>
          </div>
        </div>
      </div>
    {{/if}}
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
      @onRegisterApi={{this.registerComposerApi}}
      @isSubmitting={{this.aiBotDockedSubmit.loading}}
      @disabled={{this.isStreaming}}
      @autoResize={{true}}
      @maxResizeOffset={{this.maxResizeOffset}}
      {{didInsert this.setupScrollListener}}
      {{willDestroy this.teardownScrollListener}}
    >
      <:header>
        {{#if this.editingPost}}
          <div class="ai-bot-docked-composer__editing">
            <span class="ai-bot-docked-composer__editing-text">
              {{dAvatar this.editingPost imageSize="tiny"}}
              {{i18n "discourse_ai.ai_bot.conversations.editing_post"}}
            </span>
            <DButton
              @icon="xmark"
              @action={{this.cancelEditing}}
              class="btn-transparent ai-bot-docked-composer__editing-dismiss"
            />
          </div>
        {{/if}}
      </:header>
      <:submit as |ctx|>
        <DButton
          @icon={{if this.showToolbar "xmark" "plus"}}
          @action={{this.toggleToolbar}}
          @title={{if
            this.showToolbar
            "discourse_ai.ai_bot.conversations.hide_toolbar"
            "discourse_ai.ai_bot.conversations.show_toolbar"
          }}
          class="ai-bot-docked-composer__toolbar-toggle"
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
            class={{dConcatClass
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
              {{dIcon "chevron-down"}}
            {{/if}}
          </button>
        {{/if}}
      </:default>
    </DockedComposer>
  </template>
}
