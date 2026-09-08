import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { array } from "@ember/helper";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import didInsert from "@ember/render-modifiers/modifiers/did-insert";
import { service } from "@ember/service";
import EmojiPicker from "discourse/components/emoji-picker";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { optionalRequire } from "discourse/lib/utilities";
import { and } from "discourse/truth-helpers";
import DConditionalLoadingSpinner from "discourse/ui-kit/d-conditional-loading-spinner";
import dIcon from "discourse/ui-kit/helpers/d-icon";
import { i18n } from "discourse-i18n";

export default class VoiceChatPanel extends Component {
  @service chat;
  @service chatChannelsManager;
  @service messageBus;
  @service router;

  @tracked loading = true;
  @tracked unavailable = false;
  @tracked channel = null;
  @tracked thread = null;
  @tracked draft = "";
  @tracked sending = false;
  @tracked hideSkeleton = false;

  // Resolved at runtime rather than statically imported: cross-plugin static
  // imports aren't resolvable in the compiled plugin bundle and break the
  // whole bundle load.
  chatThread = optionalRequire(
    "discourse/plugins/chat/discourse/components/chat-thread"
  );
  // Chat's own loading skeleton doubles as the panel's loading state, so the
  // hand-off to the thread's identical skeleton reads as one continuous load
  // instead of a spinner flashing into a skeleton.
  chatSkeleton = optionalRequire(
    "discourse/plugins/chat/discourse/components/chat-skeleton"
  );

  textareaElement = null;
  #sessionPath = null;

  willDestroy() {
    super.willDestroy(...arguments);
    this.#unsubscribeSession();
    this.#deactivate();
  }

  get room() {
    return this.args.room;
  }

  get canOpenInChat() {
    return !!this.thread;
  }

  get sendDisabled() {
    return this.sending || this.draft.trim().length === 0;
  }

  @action
  async loadSession() {
    this.#subscribeSession();

    try {
      // POST prepares the session: it rolls a stale session over and follows
      // us on the channel so chat's own message endpoints accept our posts.
      // The thread itself only comes into existence with the first message.
      const data = await ajax(`/voice/rooms/${this.room.id}/chat_session`, {
        type: "POST",
      });
      await this.#applyState(data);
    } catch (e) {
      this.unavailable = true;
      popupAjaxError(e);
    } finally {
      this.loading = false;
    }
  }

  @action
  async onSessionMessage() {
    try {
      const data = await ajax(`/voice/rooms/${this.room.id}/chat_session`);
      await this.#applyState(data);
    } catch {
      // A transient refresh failure only delays the panel following a session
      // change; the next signal or reopen retries.
    }
  }

  @action
  interceptEscape(event) {
    if (event.key !== "Escape") {
      return;
    }
    if (this.thread?.draft?.editing) {
      // Let the composer's own handler cancel the in-progress edit.
      return;
    }
    // The thread composer's Escape handler "closes the pane" by routing to the
    // chat channel page, which would navigate away from the room — swallow it.
    event.stopPropagation();
  }

  @action
  openInChat() {
    if (!this.thread) {
      return;
    }
    this.router.transitionTo("chat.channel.thread", ...this.thread.routeModels);
  }

  @action
  registerTextarea(element) {
    this.textareaElement = element;
  }

  @action
  updateDraft(event) {
    this.draft = event.target.value;
    this.#autogrow();
  }

  @action
  onKeydown(event) {
    if (event.key === "Enter" && !event.shiftKey) {
      event.preventDefault();
      this.sendFirstMessage();
    }
  }

  @action
  insertEmoji(emoji) {
    const code = `:${emoji}:`;
    const element = this.textareaElement;

    if (!element) {
      this.draft = `${this.draft}${code}`;
      return;
    }

    const value = element.value;
    const start = element.selectionStart ?? value.length;
    const end = element.selectionEnd ?? value.length;
    const nextValue = `${value.slice(0, start)}${code}${value.slice(end)}`;
    element.value = nextValue;
    this.draft = nextValue;
    this.#autogrow();

    element.focus();
    const caret = start + code.length;
    element.setSelectionRange(caret, caret);
  }

  // Sends the session's opening message, which creates the thread it roots —
  // the panel then swaps to chat's own thread UI and every later message goes
  // through chat's own composer instead.
  @action
  async sendFirstMessage() {
    if (this.sendDisabled) {
      return;
    }

    this.sending = true;
    // The freshly created thread holds only this message, which loads faster
    // than the thread's skeleton can finish appearing — keep the skeleton out
    // of this swap so it doesn't flash.
    this.hideSkeleton = true;
    try {
      const data = await ajax(`/voice/rooms/${this.room.id}/chat_message`, {
        type: "POST",
        data: { message: this.draft },
      });
      // Swap to the thread UI before clearing anything: the starter composer
      // keeps the typed text until the native thread replaces it, so the panel
      // doesn't flash an empty "no chat yet" state mid-send. Clearing only on
      // success also means a rejection (a duplicate, rate limit, …) doesn't
      // eat what the user typed.
      await this.#applyState(data);
      this.draft = "";
      if (this.textareaElement) {
        this.textareaElement.value = "";
      }
    } catch (e) {
      popupAjaxError(e);
    } finally {
      this.sending = false;
    }
  }

  async #applyState(data) {
    if (!data?.channel_id || !data?.thread_id) {
      return;
    }
    if (this.thread?.id === data.thread_id && this.channel) {
      return;
    }

    const channel = await this.chatChannelsManager.find(data.channel_id);
    if (!channel.isFollowing) {
      // The server already followed us when the session was ensured; this only
      // refreshes a channel that was cached client-side before that happened.
      await this.chatChannelsManager.follow(channel);
    }
    const thread = await channel.threadsManager.find(
      channel.id,
      data.thread_id
    );

    this.channel = channel;
    this.thread = thread;

    // ChatThreadPane and the composer resolve "the current thread" from this
    // global active state, exactly like the chat drawer's router sets it —
    // without it, sending and message actions break outside chat's own routes.
    this.chat.activeChannel = channel;
    channel.activeThread = thread;
  }

  #deactivate() {
    if (this.channel && this.chat.activeChannel === this.channel) {
      // Also clears the channel's activeThread (the setter handles it).
      this.chat.activeChannel = null;
    }
  }

  #subscribeSession() {
    if (this.#sessionPath) {
      return;
    }
    this.#sessionPath = `/voice/rooms/${this.room.id}/chat`;
    this.messageBus.subscribe(this.#sessionPath, this.onSessionMessage);
  }

  #unsubscribeSession() {
    if (this.#sessionPath) {
      this.messageBus.unsubscribe(this.#sessionPath, this.onSessionMessage);
      this.#sessionPath = null;
    }
  }

  #autogrow() {
    const element = this.textareaElement;
    if (!element) {
      return;
    }
    element.style.height = "auto";
    element.style.height = `${element.scrollHeight}px`;
  }

  <template>
    <section
      aria-label={{i18n "voice.chat.title"}}
      class="voice-chat"
      {{didInsert this.loadSession}}
    >
      <header class="voice-chat__header">
        <h2 class="voice-chat__title">
          {{i18n "voice.chat.title"}}
        </h2>
        {{#if this.canOpenInChat}}
          <button
            aria-label={{i18n "voice.chat.open_in_chat"}}
            class="btn btn-transparent btn-icon no-text voice-chat__open-in-chat"
            title={{i18n "voice.chat.open_in_chat"}}
            type="button"
            {{on "click" this.openInChat}}
          >
            {{dIcon "up-right-from-square"}}
          </button>
        {{/if}}
        {{#if @onClose}}
          <button
            aria-label={{i18n "voice.chat.close"}}
            class="btn btn-icon no-text voice-chat__close"
            title={{i18n "voice.chat.close"}}
            type="button"
            {{on "click" @onClose}}
          >
            {{dIcon "xmark"}}
          </button>
        {{/if}}
      </header>

      {{! eslint-disable ember/template-no-invalid-interactive }}
      <div
        class="voice-chat__body {{if this.hideSkeleton '--hide-skeleton'}}"
        {{on "keydown" this.interceptEscape capture=true}}
      >
        {{#if this.loading}}
          {{#if this.chatSkeleton}}
            <this.chatSkeleton />
          {{else}}
            <DConditionalLoadingSpinner @condition={{true}} />
          {{/if}}
        {{else if (and this.chatThread this.thread)}}
          {{#each (array this.thread) key="id" as |thread|}}
            <this.chatThread @thread={{thread}} />
          {{/each}}
        {{else if this.unavailable}}
          <div class="voice-chat__empty">
            {{dIcon "far-comment"}}
            <p class="voice-chat__empty-title">
              {{i18n "voice.chat.unavailable"}}
            </p>
          </div>
        {{else}}
          <div class="voice-chat__empty">
            {{dIcon "far-comment"}}
            <p class="voice-chat__empty-title">
              {{i18n "voice.chat.empty_title"}}
            </p>
            <p class="voice-chat__empty-body">
              {{i18n "voice.chat.empty_body"}}
            </p>
          </div>
          <footer class="voice-chat__composer">
            <div class="voice-chat__composer-inner">
              <EmojiPicker
                @btnClass="btn-transparent voice-chat__emoji"
                @context="voice-chat"
                @didSelectEmoji={{this.insertEmoji}}
              />
              <textarea
                aria-label={{i18n "voice.chat.composer_placeholder"}}
                class="voice-chat__input"
                placeholder={{i18n "voice.chat.composer_placeholder"}}
                rows="1"
                {{didInsert this.registerTextarea}}
                {{on "input" this.updateDraft}}
                {{on "keydown" this.onKeydown}}
              ></textarea>
              <button
                aria-label={{i18n "voice.chat.send"}}
                class="btn btn-transparent btn-icon no-text voice-chat__send"
                disabled={{this.sendDisabled}}
                title={{i18n "voice.chat.send"}}
                type="button"
                {{on "click" this.sendFirstMessage}}
              >
                {{dIcon "paper-plane"}}
              </button>
            </div>
          </footer>
        {{/if}}
      </div>
    </section>
  </template>
}
