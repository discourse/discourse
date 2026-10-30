import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { array } from "@ember/helper";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { trackedObject } from "@ember/reactive/collections";
import didInsert from "@ember/render-modifiers/modifiers/did-insert";
import { next } from "@ember/runloop";
import { service } from "@ember/service";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { optionalRequire } from "discourse/lib/utilities";
import DButton from "discourse/ui-kit/d-button";
import DConditionalLoadingSpinner from "discourse/ui-kit/d-conditional-loading-spinner";
import DEmptyState from "discourse/ui-kit/d-empty-state";
import dConcatClass from "discourse/ui-kit/helpers/d-concat-class";
import dIcon from "discourse/ui-kit/helpers/d-icon";
import { i18n } from "discourse-i18n";

export default class LiveChatPanel extends Component {
  @service chat;
  @service chatChannelsManager;
  @service chatDraftsManager;
  @service liveChatDrafts;
  @service messageBus;
  @service router;
  @service site;

  @tracked loading = true;
  @tracked unavailable = false;
  @tracked channel = null;
  @tracked thread = null;
  @tracked draft = null;
  @tracked activationError = false;
  @tracked initialDraft = null;
  @tracked composerSelection = null;
  @tracked uploadDropZone = null;

  // Cross-plugin components must be resolved at runtime in compiled bundles.
  chatThread = optionalRequire(
    "discourse/plugins/chat/discourse/components/chat-thread"
  );
  chatPendingComposer = optionalRequire(
    "discourse/plugins/chat/discourse/components/chat/composer/pending-thread"
  );
  chatSkeleton = optionalRequire(
    "discourse/plugins/chat/discourse/components/chat-skeleton"
  );
  chatNavbar = optionalRequire(
    "discourse/plugins/chat/discourse/components/chat/navbar"
  );
  pane = trackedObject({ sending: false });

  #queuedState = null;
  #requestVersion = 0;
  #sessionPath = null;
  #stateVersion = 0;
  #uploadCount = 0;

  willDestroy() {
    super.willDestroy(...arguments);
    this.#stateVersion++;
    if (this.#sessionPath) {
      this.messageBus.unsubscribe(this.#sessionPath, this.onSessionMessage);
    }
    if (this.channel && this.chat.activeChannel === this.channel) {
      this.chat.activeChannel = null;
    }
  }

  get room() {
    return this.args.room;
  }

  get canOpenInChat() {
    return !!this.thread;
  }

  @action
  async loadSession() {
    this.#sessionPath = `/live/rooms/${this.room.id}/chat`;
    this.messageBus.subscribe(this.#sessionPath, this.onSessionMessage);
    const requestVersion = ++this.#requestVersion;
    try {
      const data = await ajax(`/live/rooms/${this.room.id}/chat_session`, {
        type: "POST",
      });
      if (requestVersion === this.#requestVersion) {
        await this.#applyState(data);
      }
    } catch (error) {
      if (!this.isDestroying) {
        this.unavailable = true;
        popupAjaxError(error);
      }
    } finally {
      if (!this.isDestroying) {
        this.loading = false;
      }
    }
  }

  @action
  async onSessionMessage() {
    const requestVersion = ++this.#requestVersion;
    try {
      const data = await ajax(`/live/rooms/${this.room.id}/chat_session`);
      if (requestVersion === this.#requestVersion) {
        await this.#applyState(data);
      }
    } catch {
      // Reopening or the next session signal retries a failed refresh.
    }
  }

  @action
  interceptEscape(event) {
    if (event.key === "Escape" && !this.thread?.draft?.editing) {
      event.stopPropagation();
    }
  }

  @action
  openInChat() {
    if (this.thread) {
      this.router.transitionTo(
        "chat.channel.thread",
        ...this.thread.routeModels
      );
    }
  }

  @action
  registerDropZone(element) {
    this.uploadDropZone = element;
  }

  @action
  onUploadActivity(count) {
    this.#uploadCount = count;
    if (!count) {
      next(this, this.retryActivation);
    }
  }

  @action
  resetDraft() {
    this.liveChatDrafts.clear(this.room.id, this.channel.id);
    this.draft = this.liveChatDrafts.get(this.room.id, this.channel);
  }

  @action
  async sendFirstMessage(message) {
    if (this.pane.sending || this.activationError || this.#uploadCount) {
      return;
    }
    this.pane.sending = true;
    this.#requestVersion++;
    let accepted = false;
    try {
      const data = await ajax(`/live/rooms/${this.room.id}/chat_message`, {
        type: "POST",
        data: {
          message: message.message,
          upload_ids: message.uploads.map((upload) => upload.id),
        },
      });
      accepted = true;
      this.#requestVersion++;
      this.#stateVersion++;
      if (message === this.draft) {
        this.liveChatDrafts.clear(this.room.id, message.channel.id);
      }
      if (!this.isDestroying) {
        this.draft = this.liveChatDrafts.get(this.room.id, this.channel);
        this.#queuedState = data;
      }
    } catch (error) {
      if (!this.isDestroying) {
        popupAjaxError(error);
      }
    } finally {
      if (!this.isDestroying) {
        this.pane.sending = false;
        // A rejected send stays editable even if a remote thread appeared.
        if (accepted || this.#queuedState) {
          await this.retryActivation();
        }
      }
    }
  }

  @action
  async retryActivation() {
    if (!this.#queuedState || this.pane.sending || this.#uploadCount) {
      return;
    }
    try {
      await this.#applyState(this.#queuedState);
    } catch (error) {
      if (!this.isDestroying) {
        this.activationError = true;
        popupAjaxError(error);
      }
    }
  }

  async #applyState(data) {
    if (this.isDestroying || !data?.channel_id) {
      return;
    }
    this.#queuedState = data;
    const version = ++this.#stateVersion;
    const channel = await this.chatChannelsManager.find(data.channel_id);
    if (!channel.isFollowing) {
      await this.chatChannelsManager.follow(channel);
    }
    if (!this.#isCurrent(version)) {
      return;
    }
    this.channel = channel;
    if (this.chat.activeChannel !== channel) {
      this.chat.activeChannel = channel;
    }
    this.draft ||= this.liveChatDrafts.get(this.room.id, channel);
    if (!data.thread_id || this.thread?.id === data.thread_id) {
      this.#queuedState = null;
      return;
    }
    if (this.pane.sending || this.#uploadCount) {
      return;
    }
    const thread = await channel.threadsManager.find(
      channel.id,
      data.thread_id
    );
    if (!this.#isCurrent(version) || this.pane.sending || this.#uploadCount) {
      return;
    }

    const element = this.uploadDropZone?.querySelector("textarea");
    this.composerSelection = element
      ? {
          focused: element === element.ownerDocument.activeElement,
          start: element.selectionStart,
          end: element.selectionEnd,
        }
      : null;
    this.initialDraft = null;
    const saved = this.chatDraftsManager.get(channel.id, thread.id);
    const pending = this.draft;
    if (pending.message || pending.uploads.length) {
      if (
        saved &&
        saved !== pending &&
        (saved.message || saved.uploads.length)
      ) {
        const prefixLength =
          saved.message.length + (saved.message && pending.message ? 2 : 0);
        saved.message = [saved.message, pending.message]
          .filter(Boolean)
          .join("\n\n");
        saved.uploads = Array.from(
          new Map(
            [...saved.uploads, ...pending.uploads].map((upload) => [
              upload.id,
              upload,
            ])
          ).values()
        );
        saved.editing = false;
        saved.inReplyTo = null;
        if (this.composerSelection) {
          this.composerSelection.start += prefixLength;
          this.composerSelection.end += prefixLength;
        }
        this.initialDraft = saved;
      } else {
        this.initialDraft = pending;
      }
      this.initialDraft.thread = thread;
      this.chatDraftsManager.add(this.initialDraft, channel.id, thread.id);
    }
    this.liveChatDrafts.clear(this.room.id, channel.id);
    channel.activeThread = thread;
    this.thread = thread;
    this.draft = null;
    this.activationError = false;
    this.#queuedState = null;
  }

  #isCurrent(version) {
    return !this.isDestroying && version === this.#stateVersion;
  }

  <template>
    <section
      aria-label={{i18n "live.chat.title"}}
      class={{dConcatClass "live-chat" (if this.unavailable "is-unavailable")}}
      {{didInsert this.loadSession}}
    >
      {{#if this.chatNavbar}}
        <this.chatNavbar as |navbar|>
          {{#if (and this.site.mobileView @onClose)}}
            <DButton
              class="btn-transparent no-text c-navbar__back-button"
              @action={{@onClose}}
              @ariaLabel="live.chat.close"
              @icon="chevron-left"
              @title="live.chat.close"
            />
          {{/if}}
          <navbar.Title @icon="comment" @title={{i18n "live.chat.title"}} />
          <navbar.Actions>
            {{#if this.canOpenInChat}}
              <DButton
                class="btn-transparent live-chat__open-in-chat"
                @action={{this.openInChat}}
                @ariaLabel="live.chat.open_in_chat"
                @icon="up-right-from-square"
                @title="live.chat.open_in_chat"
              />
            {{/if}}
            {{#if (and this.site.desktopView @onClose)}}
              <DButton
                class="btn-transparent live-chat__close"
                @action={{@onClose}}
                @ariaLabel="live.chat.close"
                @icon="xmark"
                @title="live.chat.close"
              />
            {{/if}}
          </navbar.Actions>
        </this.chatNavbar>
      {{/if}}

      {{! eslint-disable ember/template-no-invalid-interactive }}
      <div
        class="live-chat__body"
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
            <this.chatThread
              @channel={{this.channel}}
              @composerSelection={{this.composerSelection}}
              @initialDraft={{this.initialDraft}}
              @thread={{thread}}
            />
          {{/each}}
        {{else if this.unavailable}}
          <DEmptyState
            @svgContent={{dIcon "comment-slash"}}
            @title={{i18n "live.chat.unavailable_title"}}
          >
            <:tip>
              <div class="empty-state__tip-text">
                {{i18n "live.chat.unavailable"}}
              </div>
            </:tip>
          </DEmptyState>
        {{else if (and this.chatPendingComposer this.draft)}}
          <div class="live-chat__pending" {{didInsert this.registerDropZone}}>
            <DEmptyState
              @svgContent={{dIcon "d-chat"}}
              @title={{i18n "live.chat.empty_title"}}
            >
              <:tip>
                <div class="empty-state__tip-text">
                  {{i18n "live.chat.empty_body"}}
                </div>
              </:tip>
            </DEmptyState>
            {{#if this.activationError}}
              <DButton
                @action={{this.retryActivation}}
                @label="live.chat.retry"
              />
            {{/if}}
            <this.chatPendingComposer
              @channel={{this.channel}}
              @disabled={{this.activationError}}
              @draft={{this.draft}}
              @onResetDraft={{this.resetDraft}}
              @onSendMessage={{this.sendFirstMessage}}
              @onUploadActivity={{this.onUploadActivity}}
              @pane={{this.pane}}
              @placeholder={{i18n "live.chat.composer_placeholder"}}
              @uploadDropZone={{this.uploadDropZone}}
            />
          </div>
        {{/if}}
      </div>
    </section>
  </template>
}
