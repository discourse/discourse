import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { array } from "@ember/helper";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import didInsert from "@ember/render-modifiers/modifiers/did-insert";
import { service } from "@ember/service";
import { popupAjaxError } from "discourse/lib/ajax-error";
import DButton from "discourse/ui-kit/d-button";
import DConditionalLoadingSpinner from "discourse/ui-kit/d-conditional-loading-spinner";
import DEmptyState from "discourse/ui-kit/d-empty-state";
import dConcatClass from "discourse/ui-kit/helpers/d-concat-class";
import dIcon from "discourse/ui-kit/helpers/d-icon";
import { i18n } from "discourse-i18n";
import ChatPendingThreadComposer from "discourse/plugins/chat/discourse/components/chat/composer/pending-thread" with {
  discourseImport: "optional",
};
import ChatNavbar from "discourse/plugins/chat/discourse/components/chat/navbar" with {
  discourseImport: "optional",
};
// Chat's own loading skeleton doubles as the panel's loading state, so the hand-off to the
// thread's identical skeleton reads as one continuous load instead of a spinner flashing into
// a skeleton.
import ChatSkeleton from "discourse/plugins/chat/discourse/components/chat-skeleton" with {
  discourseImport: "optional",
};
import ChatThread from "discourse/plugins/chat/discourse/components/chat-thread" with {
  discourseImport: "optional",
};
import LiveChatPanelStateSync from "../../lib/live/chat-panel-state-sync.js";

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
  @tracked initialDraft = null;
  @tracked uploadDropZone = null;

  sessionSync = new LiveChatPanelStateSync({
    roomId: this.args.room.id,
    channelManager: this.chatChannelsManager,
    messageBus: this.messageBus,
    onChannel: (channel) => this.#setChannel(channel),
    onThread: (channel, thread) => this.#showThread(channel, thread),
  });

  willDestroy() {
    super.willDestroy(...arguments);
    this.sessionSync.dispose();
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
    try {
      await this.sessionSync.start();
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
    this.sessionSync.updateUploadCount(count);
  }

  @action
  resetDraft() {
    this.liveChatDrafts.clear(this.room.id, this.channel.id);
    this.draft = this.liveChatDrafts.get(this.room.id, this.channel);
  }

  @action
  async sendFirstMessage(message) {
    try {
      await this.sessionSync.sendFirstMessage(message, () => {
        if (message === this.draft) {
          this.liveChatDrafts.clear(this.room.id, message.channel.id);
        }
        if (!this.isDestroying) {
          this.draft = this.liveChatDrafts.get(this.room.id, this.channel);
        }
      });
    } catch (error) {
      if (!this.isDestroying) {
        popupAjaxError(error);
      }
    }
  }

  @action
  retryLoadingThread() {
    return this.sessionSync.retryLoadingThread();
  }

  #setChannel(channel) {
    this.channel = channel;
    if (this.chat.activeChannel !== channel) {
      this.chat.activeChannel = channel;
    }
    this.draft ||= this.liveChatDrafts.get(this.room.id, channel);
  }

  #showThread(channel, thread) {
    this.initialDraft = null;
    const saved = this.chatDraftsManager.get(channel.id, thread.id);
    const pending = this.draft;
    if (pending.message || pending.uploads.length) {
      if (
        saved &&
        saved !== pending &&
        (saved.message || saved.uploads.length)
      ) {
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
  }

  <template>
    <section
      aria-label={{i18n "live.chat.title"}}
      class={{dConcatClass "live-chat" (if this.unavailable "is-unavailable")}}
      {{didInsert this.loadSession}}
    >
      {{#if ChatNavbar}}
        <ChatNavbar as |navbar|>
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
        </ChatNavbar>
      {{/if}}

      {{! eslint-disable ember/template-no-invalid-interactive }}
      <div
        class="live-chat__body"
        {{on "keydown" this.interceptEscape capture=true}}
      >
        {{#if this.loading}}
          {{#if ChatSkeleton}}
            <ChatSkeleton />
          {{else}}
            <DConditionalLoadingSpinner @condition={{true}} />
          {{/if}}
        {{else if (and ChatThread this.thread)}}
          {{#each (array this.thread) key="id" as |thread|}}
            <ChatThread
              @channel={{this.channel}}
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
        {{else if (and ChatPendingThreadComposer this.draft)}}
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
            {{#if this.sessionSync.threadLoadError}}
              <DButton
                @action={{this.retryLoadingThread}}
                @label="live.chat.retry"
              />
            {{/if}}
            <ChatPendingThreadComposer
              @channel={{this.channel}}
              @disabled={{this.sessionSync.threadLoadError}}
              @draft={{this.draft}}
              @onResetDraft={{this.resetDraft}}
              @onSendMessage={{this.sendFirstMessage}}
              @onUploadActivity={{this.onUploadActivity}}
              @pane={{this.sessionSync.pane}}
              @placeholder={{i18n "live.chat.composer_placeholder"}}
              @uploadDropZone={{this.uploadDropZone}}
            />
          </div>
        {{/if}}
      </div>
    </section>
  </template>
}
