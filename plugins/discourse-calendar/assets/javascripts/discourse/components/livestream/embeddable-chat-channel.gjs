import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { array } from "@ember/helper";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { modifier } from "ember-modifier";
import { bind } from "discourse/lib/decorators";
import { and } from "discourse/truth-helpers";
import DButton from "discourse/ui-kit/d-button";
import dConcatClass from "discourse/ui-kit/helpers/d-concat-class";
import ChatChannel from "discourse/plugins/chat/discourse/components/chat-channel" with {
  discourseImport: "optional",
};

export const LIVESTREAM_CHAT_CONTEXT = "livestream-embedded-chat";

export default class EmbedableChatChannel extends Component {
  @service chatChannelsManager;
  @service currentUser;
  @service embeddableChat;
  @service messageBus;

  @tracked activeChannel;

  updateChannel = modifier(async () => {
    if (this.args.chatChannelId === this.activeChannel?.id) {
      return;
    }

    this.activeChannel = await this.chatChannelsManager.find(
      this.args.chatChannelId
    );
  });

  constructor() {
    super(...arguments);
    this.messageBus.subscribe(this.messageBusChannel, this.onMessage);
  }

  willDestroy() {
    super.willDestroy(...arguments);
    this.messageBus.unsubscribe(this.messageBusChannel, this.onMessage);
  }

  get messageBusChannel() {
    return `/discourse-calendar/livestream/chat-status/${this.currentUser.id}`;
  }

  get hiddenReferenceMessageCss() {
    // the pinned topic reference message is redundant when the chat is
    // embedded in the livestream topic it links to
    const messageId = this.activeChannel?.livestreamTopic?.reference_message_id;

    if (!messageId) {
      return "";
    }

    return `#custom-chat-container .chat-message-container[data-id="${Number(messageId)}"] { display: none; }`;
  }

  @bind
  async onMessage(message) {
    const membership = JSON.parse(message).user_channel_membership;

    if (membership.chat_channel_id !== this.activeChannel?.id) {
      return;
    }

    this.activeChannel.currentUserMembership = membership;
  }

  get showCloseButton() {
    return this.args.onClose || !this.embeddableChat.isMobileModal;
  }

  @action
  close() {
    if (this.args.onClose) {
      this.args.onClose();
      return;
    }

    this.embeddableChat.toggleChatVisibility();
  }

  <template>
    <div
      id="custom-chat-container"
      class={{dConcatClass
        (if this.embeddableChat.isMobileChatVisible "mobile")
        (unless this.embeddableChat.isMobileModal "no-modal-mobile")
      }}
      {{this.updateChannel}}
    >
      {{#if this.hiddenReferenceMessageCss}}
        {{! eslint-disable ember/template-no-forbidden-elements }}
        <style>
          {{this.hiddenReferenceMessageCss}}
        </style>
      {{/if}}
      {{#if this.showCloseButton}}
        <div class="c-navbar-container livestream-chat-close">

          <DButton
            @icon="xmark"
            @action={{this.close}}
            @title="chat.close"
            class="btn-transparent no-text c-navbar__close-drawer-button"
          />
        </div>
      {{/if}}
      <div class="chat-drawer">
        {{#if (and this.activeChannel ChatChannel)}}
          {{#each (array this.activeChannel) as |channel|}}
            <ChatChannel
              @channel={{channel}}
              @context={{LIVESTREAM_CHAT_CONTEXT}}
            />
          {{/each}}
        {{/if}}
      </div>
    </div>
  </template>
}
