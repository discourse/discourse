import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { LinkTo } from "@ember/routing";
import { service } from "@ember/service";
import { trustHTML } from "@ember/template";
import { modifier as modifierFn } from "ember-modifier";
import KeyValueStore from "discourse/lib/key-value-store";
import { eq } from "discourse/truth-helpers";
import dConcatClass from "discourse/ui-kit/helpers/d-concat-class";
import dIcon from "discourse/ui-kit/helpers/d-icon";
import dReplaceEmoji from "discourse/ui-kit/helpers/d-replace-emoji";
import { i18n } from "discourse-i18n";

export default class ChatPinnedMessageBar extends Component {
  @service chatApi;
  @service messageBus;
  @service router;
  @service siteSettings;

  @tracked pins = [];
  subscribe = modifierFn((_element, [channelId]) => {
    // Refresh from the committed pin/unpin events (re-running, and reloading,
    // whenever the channel id changes) rather than the optimistic
    // `pinnedMessagesCount`, which changes before the server confirms and
    // would refetch stale data.
    this.#hydrateDismissal(channelId);
    const key = `/chat/${channelId}`;
    this.messageBus.subscribe(
      key,
      this.onBusMessage,
      this.args.channel.channelMessageBusLastId
    );
    this.loadPins();
    return () => this.messageBus.unsubscribe(key, this.onBusMessage);
  });
  #loadSequence = 0;
  #dismissStore = new KeyValueStore("discourse_chat_pinned_bar_");

  // a user can hide the bar from the pins panel; it stays hidden until a pin
  // newer than the one they dismissed above is added
  get dismissed() {
    const dismissedAbove = this.args.channel.pinsDismissedAboveId;
    if (dismissedAbove == null) {
      return false;
    }
    const newestPinId = this.pins[0]?.id;
    return newestPinId != null && newestPinId <= dismissedAbove;
  }

  #hydrateDismissal(channelId) {
    if (this.args.channel.pinsDismissedAboveId == null) {
      const stored = this.#dismissStore.getObject(String(channelId));
      if (stored != null) {
        this.args.channel.pinsDismissedAboveId = stored;
      }
    }
  }

  get showBar() {
    return (
      this.siteSettings.chat_pinned_messages &&
      this.args.channel?.hasPinnedMessages
    );
  }

  // The viewed pin index lives on the channel so it survives the bar being
  // re-rendered (e.g. when jumping to a message reloads the message list).
  // Clamped on read so a stale index (e.g. after the viewed pin is unpinned)
  // never resolves to an undefined pin.
  get currentIndex() {
    const stored = this.args.channel.pinnedBarIndex ?? 0;
    return Math.min(stored, this.pins.length - 1);
  }

  set currentIndex(value) {
    this.args.channel.pinnedBarIndex = value;
  }

  get currentPin() {
    return this.pins[this.currentIndex];
  }

  get hasMultiplePins() {
    return this.pins.length > 1;
  }

  get pinsPanelOpen() {
    return this.router.currentRoute?.name === "chat.channel.pins";
  }

  // toggle: the see-all button opens the pins panel, or closes it (by routing
  // back to the channel) when it is already open
  get seeAllRoute() {
    return this.pinsPanelOpen ? "chat.channel" : "chat.channel.pins";
  }

  get seeAllLabel() {
    return this.pinsPanelOpen
      ? i18n("chat.pinned_messages.close")
      : i18n("chat.pinned_bar.see_all");
  }

  get currentExcerpt() {
    const message = this.currentPin?.message;
    if (message?.excerpt) {
      // server-generated, already-escaped HTML; mark safe so entities
      // (e.g. &hellip;, &amp;) and emoji render instead of being escaped again
      return trustHTML(message.excerpt);
    }
    // raw text fallback for media-only messages, left unsafe so it gets escaped
    return message?.message ?? "";
  }

  @action
  onBusMessage(busData) {
    switch (busData.type) {
      case "pin":
      case "unpin":
        this.loadPins();
        break;
      case "edit":
        // keep a pinned message's preview in sync when it gets edited
        this.#updatePinnedMessage(busData.chat_message);
        break;
    }
  }

  #updatePinnedMessage(updated) {
    const pin = updated && this.pins.find((p) => p.message?.id === updated.id);
    if (pin) {
      pin.message.message = updated.message;
      pin.message.excerpt = updated.excerpt;
    }
  }

  @action
  async loadPins() {
    if (!this.showBar) {
      this.pins = [];
      return;
    }

    const sequence = ++this.#loadSequence;
    try {
      const pins = await this.chatApi.pinnedMessages(this.args.channel);
      // ignore a slow response a newer load has already superseded
      if (sequence === this.#loadSequence) {
        this.pins = pins;
      }
    } catch {
      // keep the previously loaded pins on a transient failure
    }
  }

  @action
  jumpToCurrentPin() {
    const pin = this.currentPin;
    if (!pin) {
      return;
    }

    this.args.onJumpToMessage?.(pin.message.id);

    // walk to the next pin so repeated taps cycle through all of them
    if (this.hasMultiplePins) {
      this.currentIndex = (this.currentIndex + 1) % this.pins.length;
    }
  }

  <template>
    {{#if this.showBar}}
      <div
        class={{dConcatClass
          "chat-pinned-bar"
          (if this.currentPin "" "--loading")
          (if this.dismissed "--dismissed")
        }}
        {{this.subscribe @channel.id}}
      >
        {{#if this.currentPin}}
          <button
            type="button"
            class="chat-pinned-bar__main"
            aria-label={{i18n "chat.pinned_bar.jump_to_pinned"}}
            {{on "click" this.jumpToCurrentPin}}
          >
            {{#if this.hasMultiplePins}}
              <span class="chat-pinned-bar__indicator" aria-hidden="true">
                {{#each this.pins as |pin index|}}
                  <span
                    class={{if
                      (eq index this.currentIndex)
                      "chat-pinned-bar__indicator-segment --active"
                      "chat-pinned-bar__indicator-segment"
                    }}
                  ></span>
                {{/each}}
              </span>
            {{/if}}

            <span class="chat-pinned-bar__content">
              <span class="chat-pinned-bar__label">
                {{dIcon "thumbtack"}}
                {{i18n "chat.pinned_bar.title"}}
              </span>
              <span class="chat-pinned-bar__excerpt">
                {{dReplaceEmoji this.currentExcerpt}}
              </span>
            </span>
          </button>
        {{/if}}

        <LinkTo
          @route={{this.seeAllRoute}}
          @models={{@channel.routeModels}}
          class={{if
            this.pinsPanelOpen
            "chat-pinned-bar__see-all btn no-text btn-transparent --active"
            "chat-pinned-bar__see-all btn no-text btn-transparent"
          }}
          aria-label={{this.seeAllLabel}}
          title={{this.seeAllLabel}}
        >
          {{dIcon "list"}}
          {{#if @channel.hasUnseenPins}}
            <span class="chat-pinned-bar__unread-indicator"></span>
          {{/if}}
        </LinkTo>
      </div>
    {{/if}}
  </template>
}
