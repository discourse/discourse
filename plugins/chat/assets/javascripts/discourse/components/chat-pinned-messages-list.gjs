import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { fn } from "@ember/helper";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { getOwner } from "@ember/owner";
import { LinkTo } from "@ember/routing";
import { schedule } from "@ember/runloop";
import { service } from "@ember/service";
import { modifier as modifierFn } from "ember-modifier";
import DButton from "discourse/ui-kit/d-button";
import dIcon from "discourse/ui-kit/helpers/d-icon";
import { i18n } from "discourse-i18n";
import ChatMessage from "discourse/plugins/chat/discourse/components/chat-message";
import ChatMessageInteractor from "discourse/plugins/chat/discourse/lib/chat-message-interactor";
import {
  dismissPinsUpTo,
  hasPinsDismissal,
  newestPinId,
  resetPinsDismissal,
} from "discourse/plugins/chat/discourse/lib/chat-pinned-bar-dismissal";

export default class ChatPinnedMessagesList extends Component {
  @service a11y;
  @service messageBus;
  @service chatApi;
  @service currentUser;
  @service router;
  @service siteSettings;

  @tracked pinnedMessages = this.args.pinnedMessages || [];

  subscribe = modifierFn((element) => {
    const channel = this.args.channel;
    this.#element = element;

    this.messageBus.subscribe(
      `/chat/${channel.id}`,
      this.onMessage,
      channel.channelMessageBusLastId
    );

    // @pinnedMessages can be stale (the drawer caches its route model)
    this.#loadPins(channel);
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
  #element = null;
  #inFlightUnpins = new Set();
  #loadSequence = 0;

  #lastViewedPinsAtSnapshot =
    this.args.channel.currentUserMembership?.lastViewedPinsAt;

  get canToggleDismissal() {
    return this.pinnedMessages.length > 0;
  }

  get barDismissed() {
    return hasPinsDismissal(this.args.channel);
  }

  get canManagePins() {
    return (
      this.siteSettings.chat_pinned_messages && this.args.channel?.canManagePins
    );
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

  // the interactor owns channel-wide pin state, including the
  // pendingOptimisticUnpins handshake that stops the message-bus handler from
  // decrementing the count a second time; this panel owns only its own list
  @action
  async unpin(pin) {
    const messageId = pin.message.id;

    if (this.#inFlightUnpins.has(messageId)) {
      return;
    }
    // kept on success until a pin event re-pins the message, so fetches
    // started before the unpin can't restore the row
    this.#inFlightUnpins.add(messageId);

    const removedIndex = this.pinnedMessages.indexOf(pin);
    this.pinnedMessages = this.pinnedMessages.filter(
      (existingPin) => existingPin.message.id !== messageId
    );
    this.#focusAfterRemoval(removedIndex);

    await new ChatMessageInteractor(
      getOwner(this),
      pin.message,
      "channel"
    ).unpin();

    // the interactor re-pins its message when the request failed
    if (pin.message.pinned) {
      this.#inFlightUnpins.delete(messageId);
      this.#restorePin(pin);
      return;
    }

    // the row is gone and focus lands on a button with the same label, so
    // say what happened
    this.a11y.announce(i18n("chat.pinned_messages.message_unpinned"), "polite");
  }

  #restorePin(pin) {
    if (this.isDestroying || this.pinnedMessages.includes(pin)) {
      return;
    }

    // pins render in channel timeline order
    this.pinnedMessages = [...this.pinnedMessages, pin].sort(
      (a, b) => a.message.id - b.message.id
    );
  }

  // a removed row must not drop focus to <body>
  #focusAfterRemoval(removedIndex) {
    schedule("afterRender", () => {
      if (this.isDestroying || !this.#element) {
        return;
      }

      const buttons = [
        ...this.#element.querySelectorAll(".chat-pinned-message__unpin"),
      ];

      const target =
        buttons[removedIndex] ??
        buttons.at(-1) ??
        this.#element.querySelector(".chat-pinned-messages-list__empty");

      target?.focus();
    });
  }

  async #loadPins(channel) {
    const sequence = ++this.#loadSequence;

    try {
      const pinnedMessages = await this.chatApi.pinnedMessages(channel);

      if (this.isDestroying || sequence !== this.#loadSequence) {
        return;
      }

      this.pinnedMessages = pinnedMessages.filter(
        (pin) => !this.#inFlightUnpins.has(pin.message.id)
      );
    } catch {
      // best-effort refresh
    }
  }

  handlePinMessage(data) {
    this.#inFlightUnpins.delete(data.chat_message_id);

    const existingPin = this.pinnedMessages.find(
      (pin) => pin.message.id === data.chat_message_id
    );

    if (existingPin) {
      return;
    }

    this.#loadPins(this.args.channel).then(() => {
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
          <div class="chat-pinned-message">
            <LinkTo
              @route="chat.channel.near-message"
              @models={{this.routeModels pin}}
              class="chat-pinned-message__link"
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

            {{#if this.canManagePins}}
              <DButton
                @icon="thumbtack-slash"
                @title="chat.unpin_message"
                @ariaLabel="chat.unpin_message"
                @action={{fn this.unpin pin}}
                class="btn-transparent chat-pinned-message__unpin"
              />
            {{/if}}
          </div>
        {{else}}
          <div class="chat-pinned-messages-list__empty" tabindex="-1">
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
