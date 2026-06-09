import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { array } from "@ember/helper";
import { service } from "@ember/service";
import { modifier } from "ember-modifier";
import { bind } from "discourse/lib/decorators";
import { optionalRequire } from "discourse/lib/utilities";
import { and } from "discourse/truth-helpers";
import DButton from "discourse/ui-kit/d-button";
import dConcatClass from "discourse/ui-kit/helpers/d-concat-class";

export default class EmbedableChatChannel extends Component {
  @service chatChannelsManager;
  @service currentUser;
  @service embeddableChat;
  @service messageBus;

  @tracked activeChannel;

  // Resolved at runtime rather than statically imported: cross-plugin static
  // imports aren't resolvable in the compiled plugin bundle and break the whole
  // bundle load.
  chatChannelComponent = optionalRequire(
    "discourse/plugins/chat/discourse/components/chat-channel"
  );

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

  @bind
  async onMessage(message) {
    const membership = JSON.parse(message).user_channel_membership;

    if (membership.chat_channel_id !== this.activeChannel?.id) {
      return;
    }

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
        {{#if (and this.activeChannel this.chatChannelComponent)}}
          {{#each (array this.activeChannel) as |channel|}}
            <this.chatChannelComponent @channel={{channel}} />
          {{/each}}
        {{/if}}
      </div>
    </div>
  </template>
}
