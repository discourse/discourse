import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { array } from "@ember/helper";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import didInsert from "@ember/render-modifiers/modifiers/did-insert";
import { service } from "@ember/service";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { optionalRequire } from "discourse/lib/utilities";
import { and } from "discourse/truth-helpers";
import DButton from "discourse/ui-kit/d-button";
import DConditionalLoadingSpinner from "discourse/ui-kit/d-conditional-loading-spinner";
import DEmptyState from "discourse/ui-kit/d-empty-state";
import dConcatClass from "discourse/ui-kit/helpers/d-concat-class";
import dIcon from "discourse/ui-kit/helpers/d-icon";
import { i18n } from "discourse-i18n";

export default class VoiceChatPanel extends Component {
  @service chat;
  @service chatChannelsManager;
  @service messageBus;
  @service router;
  @service site;

  @tracked loading = true;
  @tracked unavailable = false;
  @tracked channel = null;
  @tracked thread = null;
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
  chatNavbar = optionalRequire(
    "discourse/plugins/chat/discourse/components/chat/navbar"
  );

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

  // Starts the session's thread with a short opener posted as the user, so
  // the panel can hand over to chat's own thread UI and composer.
  @action
  async startChat() {
    if (this.sending) {
      return;
    }

    this.sending = true;
    // The freshly created thread holds only the opener, which loads faster
    // than the thread's skeleton can finish appearing — keep the skeleton out
    // of this swap so it doesn't flash.
    this.hideSkeleton = true;
    try {
      const data = await ajax(`/voice/rooms/${this.room.id}/chat_message`, {
        type: "POST",
      });
      await this.#applyState(data);
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

  <template>
    <section
      aria-label={{i18n "voice.chat.title"}}
      class={{dConcatClass "voice-chat" (if this.unavailable "is-unavailable")}}
      {{didInsert this.loadSession}}
    >
      {{#if this.chatNavbar}}
        <this.chatNavbar as |navbar|>
          {{#if (and this.site.mobileView @onClose)}}
            <DButton
              class="btn-transparent no-text c-navbar__back-button"
              @action={{@onClose}}
              @ariaLabel="voice.chat.close"
              @icon="chevron-left"
              @title="voice.chat.close"
            />
          {{/if}}
          <navbar.Title @icon="comment" @title={{i18n "voice.chat.title"}} />
          <navbar.Actions>
            {{#if this.canOpenInChat}}
              <DButton
                class="btn-transparent voice-chat__open-in-chat"
                @action={{this.openInChat}}
                @ariaLabel="voice.chat.open_in_chat"
                @icon="up-right-from-square"
                @title="voice.chat.open_in_chat"
              />
            {{/if}}
            {{#if (and this.site.desktopView @onClose)}}
              <DButton
                class="btn-transparent voice-chat__close"
                @action={{@onClose}}
                @ariaLabel="voice.chat.close"
                @icon="xmark"
                @title="voice.chat.close"
              />
            {{/if}}
          </navbar.Actions>
        </this.chatNavbar>
      {{/if}}

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
          <DEmptyState
            @svgContent={{dIcon "comment-slash"}}
            @title={{i18n "voice.chat.unavailable_title"}}
          >
            <:tip>
              <div class="empty-state__tip-text">
                {{i18n "voice.chat.unavailable"}}
              </div>
            </:tip>
          </DEmptyState>
        {{else}}
          <DEmptyState
            @ctaAction={{this.startChat}}
            @ctaDisabled={{this.sending}}
            @ctaLabel={{i18n "voice.chat.start"}}
            @svgContent={{dIcon "d-chat"}}
            @title={{i18n "voice.chat.empty_title"}}
          />
        {{/if}}
      </div>
    </section>
  </template>
}
