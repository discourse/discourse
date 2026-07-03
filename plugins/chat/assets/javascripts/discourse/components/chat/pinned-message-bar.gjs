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
} from "discourse/plugins/chat/discourse/lib/chat-pinned-bar-dismissal";

// Most indicator bars visible at once. Up to this many pins each get their own
// bar and the highlight slides between them; beyond it the highlight stays
// centred and the bars stream past it (scrolling) as you move through.
const INDICATOR_WINDOW = 4;

// Indicator geometry, in px. The strip fills ~the bar's text height; the
// visible bars split it evenly, so fewer pins => taller bars. Sizes are
// computed as whole pixels here (rather than dividing in CSS) so every bar
// renders identically instead of drifting on sub-pixel rounding.
const INDICATOR_HEIGHT = 30;
const SEGMENT_GAP = 2;
// Edge fade applied to whichever side has more pins, so bars dissolve as they
// scroll past the centred highlight instead of popping in/out.
const INDICATOR_FADE = 8;

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

  // A user can hide the bar from the pins panel; it stays hidden until a pin
  // newer than the one they dismissed above is added (see
  // lib/chat-pinned-bar-dismissal). Pin managers bypass any stored dismissal —
  // they curate the pins, so the bar always shows for them (this also
  // un-sticks a dismissal recorded before a user gained manage rights).
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

  // Index of the first bar visible in the indicator. The active bar is kept
  // around the middle of the window so the bars stream past it (with the
  // trailing edge fading) as the rail scrolls, rather than the highlight
  // parking at an edge where the scroll would be invisible.
  get indicatorTop() {
    const total = this.pins.length;
    if (total <= INDICATOR_WINDOW) {
      return 0;
    }
    const top = this.currentIndex - Math.floor(INDICATOR_WINDOW / 2);
    return Math.max(0, Math.min(top, total - INDICATOR_WINDOW));
  }

  // Number of bars actually on screen: the window, or fewer when there aren't
  // enough pins to fill it. Drives the bar height so the strip always fills
  // the bar (few pins => taller bars) rather than floating.
  get visibleSegments() {
    return Math.min(this.pins.length, INDICATOR_WINDOW);
  }

  get indicatorStyle() {
    const visible = this.visibleSegments;
    // even whole-pixel bars that fill the height, with gaps only between;
    // floor (not round) so the strip never exceeds INDICATOR_HEIGHT
    const segment = Math.floor(
      (INDICATOR_HEIGHT - SEGMENT_GAP * (visible - 1)) / visible
    );
    const height = segment * visible + SEGMENT_GAP * (visible - 1);
    const top = this.indicatorTop;
    // fade whichever edge has more pins beyond it, so the scroll reads
    const fadeTop = top > 0 ? INDICATOR_FADE : 0;
    const fadeBottom = top < this.pins.length - visible ? INDICATOR_FADE : 0;
    return trustHTML(
      `--chat-pinned-bar-seg: ${segment}px; ` +
        `--chat-pinned-bar-gap: ${SEGMENT_GAP}px; ` +
        `--chat-pinned-bar-indicator-height: ${height}px; ` +
        `--chat-pinned-bar-indicator-top: ${top}; ` +
        // thumb sits inside the track (which already offsets by -top), so its
        // own position is the full-list index
        `--chat-pinned-bar-active: ${this.currentIndex}; ` +
        `--chat-pinned-bar-fade-top: ${fadeTop}px; ` +
        `--chat-pinned-bar-fade-bottom: ${fadeBottom}px`
    );
  }

  // With a single pin, the see-all button gives way to an inline dismiss (X) —
  // there is no list worth opening, and the pin can be hidden in one tap.
  // Managers keep the list button; they never dismiss.
  get showInlineDismiss() {
    return !this.hasMultiplePins && !this.args.channel.canManagePins;
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
                  {{#each this.pins as |pin|}}
                    <span
                      class="chat-pinned-bar__indicator-segment"
                      data-pin-id={{pin.id}}
                    ></span>
                  {{/each}}
                  {{! a single bright bar that slides to the active pin }}
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
