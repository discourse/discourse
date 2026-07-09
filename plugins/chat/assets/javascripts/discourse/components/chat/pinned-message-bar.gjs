import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { LinkTo } from "@ember/routing";
import { service } from "@ember/service";
import { trustHTML } from "@ember/template";
import { modifier as modifierFn } from "ember-modifier";
import DButton from "discourse/ui-kit/d-button";
import dConcatClass from "discourse/ui-kit/helpers/d-concat-class";
import dIcon from "discourse/ui-kit/helpers/d-icon";
import dReplaceEmoji from "discourse/ui-kit/helpers/d-replace-emoji";
import { i18n } from "discourse-i18n";
import {
  dismissPinsUpTo,
  newestPinId,
  pinsDismissedAboveId,
  resetPinsDismissal,
} from "discourse/plugins/chat/discourse/lib/chat-pinned-bar-dismissal";

const INDICATOR_WINDOW = 4;
const INDICATOR_HEIGHT = 30; // px
const SEGMENT_GAP = 2; // px
const INDICATOR_FADE = 8; // px

export default class ChatPinnedMessageBar extends Component {
  @service chatApi;
  @service messageBus;
  @service router;
  @service siteSettings;

  @tracked pins = [];
  subscribe = modifierFn((_element, [channelId]) => {
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

  get dismissed() {
    if (this.args.channel.canManagePins) {
      return false;
    }
    const dismissedAbove = pinsDismissedAboveId(this.args.channel);
    if (dismissedAbove == null || this.pins.length === 0) {
      return false;
    }
    return newestPinId(this.pins) <= dismissedAbove;
  }

  get showBar() {
    return (
      this.siteSettings.chat_pinned_messages &&
      this.args.channel?.hasPinnedMessages
    );
  }

  get orderedPins() {
    return [...this.pins].sort((a, b) => a.message.id - b.message.id);
  }

  // the newest pin at or above the viewport bottom — the one governing the view
  get currentPin() {
    const pins = this.orderedPins;
    if (pins.length === 0) {
      return null;
    }
    // a tapped pin overrides the anchor until chat-channel clears it on scroll
    const tappedId = this.args.channel.activePinnedMessageId;
    if (tappedId != null) {
      const tapped = pins.find((pin) => pin.message.id === tappedId);
      if (tapped) {
        return tapped;
      }
    }
    const bottomId = this.args.viewportBottomMessageId;
    if (bottomId == null) {
      return pins[pins.length - 1];
    }
    let active = pins[0];
    for (const pin of pins) {
      if (pin.message.id > bottomId) {
        break;
      }
      active = pin;
    }
    return active;
  }

  get currentIndex() {
    return Math.max(0, this.orderedPins.indexOf(this.currentPin));
  }

  get hasMultiplePins() {
    return this.pins.length > 1;
  }

  get indicatorTop() {
    const total = this.pins.length;
    if (total <= INDICATOR_WINDOW) {
      return 0;
    }
    const top = this.currentIndex - Math.floor(INDICATOR_WINDOW / 2);
    return Math.max(0, Math.min(top, total - INDICATOR_WINDOW));
  }

  get visibleSegments() {
    return Math.min(this.pins.length, INDICATOR_WINDOW);
  }

  get indicatorStyle() {
    const visible = this.visibleSegments;
    const segment = Math.floor(
      (INDICATOR_HEIGHT - SEGMENT_GAP * (visible - 1)) / visible
    );
    const height = segment * visible + SEGMENT_GAP * (visible - 1);
    const top = this.indicatorTop;
    const fadeTop = top > 0 ? INDICATOR_FADE : 0;
    const fadeBottom = top < this.pins.length - visible ? INDICATOR_FADE : 0;
    return trustHTML(
      `--chat-pinned-bar-seg: ${segment}px; ` +
        `--chat-pinned-bar-gap: ${SEGMENT_GAP}px; ` +
        `--chat-pinned-bar-indicator-height: ${height}px; ` +
        `--chat-pinned-bar-indicator-top: ${top}; ` +
        `--chat-pinned-bar-active: ${this.currentIndex}; ` +
        `--chat-pinned-bar-fade-top: ${fadeTop}px; ` +
        `--chat-pinned-bar-fade-bottom: ${fadeBottom}px`
    );
  }

  get showInlineDismiss() {
    return !this.hasMultiplePins && !this.args.channel.canManagePins;
  }

  get pinsPanelOpen() {
    return this.router.currentRoute?.name === "chat.channel.pins";
  }

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
      // excerpt is server-escaped HTML — trust it so entities/emoji aren't re-escaped
      return trustHTML(message.excerpt);
    }
    // media-only fallback: leave untrusted so the template escapes it
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
      if (sequence === this.#loadSequence) {
        this.pins = pins;
        this.#reconcileDismissal();
      }
    } catch {
      // keep the previously loaded pins on a transient failure
    }
  }

  #reconcileDismissal() {
    const dismissedAbove = pinsDismissedAboveId(this.args.channel);
    if (dismissedAbove != null && newestPinId(this.pins) > dismissedAbove) {
      resetPinsDismissal(this.args.channel);
    }
  }

  @action
  jumpToCurrentPin() {
    // jump to the shown pin, then preview the next older one (wraps oldest -> newest)
    const pins = this.orderedPins;
    const current = this.currentPin;
    if (!current) {
      return;
    }
    this.args.onJumpToMessage?.(current.message.id);
    const index = pins.indexOf(current);
    const next = index <= 0 ? pins[pins.length - 1] : pins[index - 1];
    this.args.channel.activePinnedMessageId = next.message.id;
  }

  @action
  dismiss() {
    dismissPinsUpTo(this.args.channel, newestPinId(this.pins));
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
              <span
                class="chat-pinned-bar__indicator"
                aria-hidden="true"
                style={{this.indicatorStyle}}
              >
                <span class="chat-pinned-bar__indicator-track">
                  {{#each this.orderedPins as |pin|}}
                    <span
                      class="chat-pinned-bar__indicator-segment"
                      data-pin-id={{pin.id}}
                    ></span>
                  {{/each}}
                  <span class="chat-pinned-bar__indicator-thumb"></span>
                </span>
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

        {{#if this.showInlineDismiss}}
          <DButton
            @action={{this.dismiss}}
            @icon="xmark"
            @title="chat.pinned_bar.dismiss"
            @ariaLabel="chat.pinned_bar.dismiss"
            class="chat-pinned-bar__dismiss btn-transparent no-text"
          />
        {{else}}
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
        {{/if}}
      </div>
    {{/if}}
  </template>
}
