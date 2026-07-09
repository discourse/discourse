import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { fn } from "@ember/helper";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { LinkTo } from "@ember/routing";
import { service } from "@ember/service";
import { modifier as modifierFn } from "ember-modifier";
import DButton from "discourse/ui-kit/d-button";
import dIcon from "discourse/ui-kit/helpers/d-icon";
import { i18n } from "discourse-i18n";
import ChatMessage from "discourse/plugins/chat/discourse/components/chat-message";
import {
  dismissPinsUpTo,
  hasPinsDismissal,
  newestPinId,
  resetPinsDismissal,
} from "discourse/plugins/chat/discourse/lib/chat-pinned-bar-dismissal";

export default class ChatPinnedMessagesList extends Component {
  @service messageBus;
  @service chatApi;
  @service currentUser;
  @service router;

  @tracked pinnedMessages = this.args.pinnedMessages || [];

  subscribe = modifierFn(() => {
    const channel = this.args.channel;

    this.messageBus.subscribe(
      `/chat/${channel.id}`,
      this.onMessage,
      channel.channelMessageBusLastId
    );

    this.#markPinsAsRead(channel);

    return () => {
      this.messageBus.unsubscribe(`/chat/${channel.id}`, this.onMessage);
      this.#markPinsAsRead(channel);
    };
  });
  onMessage = (busData) => {
    switch (busData.type) {
      case "pin":
        this.handlePinMessage(busData);
        break;
      case "unpin":
        this.handleUnpinMessage(busData);
        break;
    }
  };
  isUnseen = (pin) => {
    if (pin.pinned_by?.id === this.currentUser?.id) {
      return false;
    }

    if (!this.#lastViewedPinsAtSnapshot) {
      return true;
    }

    const pinnedAt = new Date(pin.pinned_at);
    const lastViewed = new Date(this.#lastViewedPinsAtSnapshot);
    return pinnedAt > lastViewed;
  };
  decorateMessage = (pin) => {
    pin.message.isUnseen = this.isUnseen(pin);
    return pin.message;
  };
  pinnedByText = (pin) => {
    if (pin.pinned_by?.id === this.currentUser?.id) {
      return i18n("chat.pinned_messages.pinned_by_you");
    }
    return i18n("chat.pinned_messages.pinned_by_user", {
      username: pin.pinned_by?.username,
    });
  };
  routeModels = (pin) => {
    return [...this.args.channel.routeModels, pin.message.id];
  };
  #lastViewedPinsAtSnapshot =
    this.args.channel.currentUserMembership?.lastViewedPinsAt;

  // not managers — "Dismiss pinned messages" would read as unpinning for all
  get canToggleDismissal() {
    return this.pinnedMessages.length > 0 && !this.args.channel.canManagePins;
  }

  get barDismissed() {
    return hasPinsDismissal(this.args.channel);
  }

  // mirror the visited pin in the bar (the jump's scroll wouldn't update it)
  @action
  visitPin(pin) {
    this.args.channel.activePinnedMessageId = pin.message.id;
  }

  @action
  dismissBar() {
    const channel = this.args.channel;
    dismissPinsUpTo(channel, newestPinId(this.pinnedMessages));
    this.router.transitionTo("chat.channel", ...channel.routeModels);
  }

  @action
  showBar() {
    const channel = this.args.channel;
    resetPinsDismissal(channel);
    this.router.transitionTo("chat.channel", ...channel.routeModels);
  }

  handlePinMessage(data) {
    const existingPin = this.pinnedMessages.find(
      (pin) => pin.message.id === data.chat_message_id
    );

    if (existingPin) {
      return;
    }

    this.chatApi.pinnedMessages(this.args.channel).then((pinnedMessages) => {
      this.pinnedMessages = pinnedMessages;

      // If current user pinned this message, update timestamp so it doesn't show as unseen
      if (
        this.args.channel.currentUserMembership &&
        data.pinned_by_id === this.currentUser.id
      ) {
        this.args.channel.currentUserMembership.lastViewedPinsAt = new Date();
      }
    });
  }

  #markPinsAsRead(channel) {
    if (channel.currentUserMembership) {
      channel.currentUserMembership.lastViewedPinsAt = new Date();
      channel.currentUserMembership.hasUnseenPins = false;
      this.chatApi.markPinsAsRead(channel.id).catch(() => {});
    }
  }

  handleUnpinMessage(data) {
    this.pinnedMessages = this.pinnedMessages.filter(
      (pin) => pin.message.id !== data.chat_message_id
    );
  }

  <template>
    <div
      class="chat-pinned-messages-list chat-messages-scroller"
      {{this.subscribe}}
    >
      <div class="chat-pinned-messages-list__items">
        {{#each this.pinnedMessages as |pin|}}
          <LinkTo
            @route="chat.channel.near-message"
            @models={{this.routeModels pin}}
            class="chat-pinned-message"
            {{on "click" (fn this.visitPin pin)}}
          >
            <ChatMessage
              @message={{this.decorateMessage pin}}
              @context="pinned"
              @includeSeparator={{false}}
              @interactive={{false}}
            >
              <:top>
                <div class="chat-pinned-message__pinned-by">
                  {{#if (this.isUnseen pin)}}
                    {{dIcon
                      "thumbtack"
                      class="chat-pinned-message__pinned-by-icon"
                    }}
                  {{/if}}
                  <span>{{this.pinnedByText pin}}</span>
                </div>
              </:top>
            </ChatMessage>
          </LinkTo>
        {{else}}
          <div class="chat-pinned-messages-list__empty">
            {{i18n "chat.no_pinned_messages"}}
          </div>
        {{/each}}
      </div>

      {{#if this.canToggleDismissal}}
        <div class="chat-pinned-messages-list__footer">
          {{#if this.barDismissed}}
            <DButton
              @action={{this.showBar}}
              @label="chat.pinned_messages.show"
              class="btn-flat chat-pinned-messages-list__show"
            />
          {{else}}
            <DButton
              @action={{this.dismissBar}}
              @label="chat.pinned_messages.dismiss"
              class="btn-flat chat-pinned-messages-list__dismiss"
            />
          {{/if}}
        </div>
      {{/if}}
    </div>
  </template>
}
