import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { array } from "@ember/helper";
import { service } from "@ember/service";
import { modifier } from "ember-modifier";
import { bind } from "discourse/lib/decorators";
import DButton from "discourse/ui-kit/d-button";
import dConcatClass from "discourse/ui-kit/helpers/d-concat-class";
import ChatChannel from "discourse/plugins/chat/discourse/components/chat-channel";

export default class EmbedableChatChannel extends Component {
  @service chatChannelsManager;
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
    this.messageBus.subscribe(
      "discourse_livestream_update_livestream_chat_status",
      this.onMessage
    );
  }

  willDestroy() {
    super.willDestroy(...arguments);
    this.messageBus.unsubscribe(
      "discourse_livestream_update_livestream_chat_status",
      this.onMessage
    );
  }

  @bind
  async onMessage(membership) {
    membership = JSON.parse(membership).user_channel_membership;
    this.activeChannel.currentUserMembership = membership;
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
      {{#unless this.embeddableChat.isMobileModal}}
        <div class="c-navbar-container livestream-chat-close">

          <DButton
            @icon="xmark"
            @action={{this.embeddableChat.toggleChatVisibility}}
            @title="chat.close"
            class="btn-transparent no-text c-navbar__close-drawer-button"
          />
        </div>
      {{/unless}}
      <div class="chat-drawer">
        {{#if this.activeChannel}}
          {{#each (array this.activeChannel) as |channel|}}
            <ChatChannel @channel={{channel}} />
          {{/each}}
        {{/if}}
      </div>
    </div>
  </template>
}
