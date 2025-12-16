import { setOwner } from "@ember/owner";
import { schedule } from "@ember/runloop";
import { service } from "@ember/service";
import { tracked } from "@glimmer/tracking";
import { bind } from "discourse/lib/decorators";
import userPresent, {
  onPresenceChange,
  removeOnPresenceChange,
} from "discourse/lib/user-presence";
import { maintainScrollPosition } from "discourse/plugins/chat/discourse/lib/scroll-helpers";

const CHAT_PRESENCE_OPTIONS = {
  userUnseenTime: 1 * 60 * 1000,
  browserHiddenTime: 0,
};

/**
 * Shared state and helpers for chat panes (channel and thread).
 *
 * Manages:
 * - User presence detection (is the user actively viewing the tab?)
 * - Pending message tracking (messages that arrived while scrolled away)
 * - Pending content indicator visibility
 *
 * Used via composition rather than inheritance so callers can be explicit
 * about which behaviors they're invoking.
 *
 * @example
 * ```js
 * this.paneState = new ChatPaneState(getOwner(this), {
 *   contextKey: `channel:${this.channel.id}`,
 *   onUserPresent: this.handleUserReturned,
 * });
 * // Call teardown() when done
 * ```
 */
export default class ChatPaneState {
  @service chatPanePendingManager;

  /**
   * Whether the user is currently present (tab visible and recently active).
   *
   * @type {boolean}
   */
  @tracked userIsPresent = true;

  /**
   * Whether there is pending content below the current scroll position.
   * True when there are pending messages or the user is scrolled away.
   *
   * @type {boolean}
   */
  @tracked hasPendingContentBelow = false;

  /**
   * Identifier for this chat context (e.g. "channel-123" or "thread-456").
   * Used to track pending messages per-context in ChatPanePendingManager.
   *
   * @type {string | null}
   */
  contextKey = null;

  /**
   * Callback invoked when user returns after being away.
   *
   * @type {(() => void) | null}
   */
  #onUserPresent = null;

  /**
   * @param {object} owner - The Ember owner for dependency injection
   * @param {object} options
   * @param {string} options.contextKey - The context identifier (e.g. "channel-123")
   * @param {(() => void) | null} [options.onUserPresent] - Called when user returns
   */
  constructor(owner, options) {
    setOwner(this, owner);
    this.contextKey = options.contextKey;
    this.#onUserPresent = options.onUserPresent ?? null;
    this.userIsPresent = userPresent(CHAT_PRESENCE_OPTIONS);
    onPresenceChange({
      callback: this.onPresenceChangeCallback,
      ...CHAT_PRESENCE_OPTIONS,
    });
  }

  /**
   * Cleanup presence tracking. Call from component teardown (e.g. willDestroy).
   */
  teardown() {
    removeOnPresenceChange(this.onPresenceChangeCallback);
    this.clearPendingMessages();
  }

  /**
   * Whether there are pending messages for this context.
   * Reads from ChatPanePendingManager (the single source of truth).
   *
   * @returns {boolean}
   */
  get hasPendingMessages() {
    return this.chatPanePendingManager.hasPending(this.contextKey);
  }

  /**
   * Checks if the scroller element has overflow (can scroll).
   *
   * @param {HTMLElement | null} scroller
   * @returns {boolean}
   */
  #canScroll(scroller) {
    if (!scroller) {
      return false;
    }

    // Use a small tolerance because scrollHeight and clientHeight can
    // occasionally differ by subpixel rounding.
    return scroller.scrollHeight - scroller.clientHeight > 1;
  }

  /**
   * Computes whether the user is scrolled away from the bottom.
   * True if there are more messages to load OR they've scrolled up past the threshold.
   *
   * @param {object} options
   * @param {boolean} options.fetchedOnce - Whether initial fetch has completed
   * @param {boolean} options.canLoadMoreFuture - Whether more future messages exist
   * @param {number} options.distanceToBottomPixels - Current distance from bottom
   * @param {number} [options.distanceThresholdPixels=250] - Threshold to trigger "scrolled away"
   * @returns {boolean}
   */
  #computeIsScrolledAway(options) {
    const {
      fetchedOnce,
      canLoadMoreFuture,
      distanceToBottomPixels,
      distanceThresholdPixels = 250,
    } = options;

    return (
      (fetchedOnce && canLoadMoreFuture) ||
      distanceToBottomPixels > distanceThresholdPixels
    );
  }

  /**
   * Updates hasPendingContentBelow based on scroll position and loader state.
   *
   * @param {object} options
   * @param {HTMLElement | null} options.scroller
   * @param {boolean} options.fetchedOnce
   * @param {boolean} options.canLoadMoreFuture
   * @param {number} options.distanceToBottomPixels
   * @param {number} [options.distanceThresholdPixels]
   */
  #updateHasPendingContentBelow(options) {
    const { scroller } = options;
    const isScrolledAway = this.#computeIsScrolledAway(options);
    this.hasPendingContentBelow = this.#computeHasPendingContentBelow(
      scroller,
      isScrolledAway
    );
  }

  /**
   * Update pending content state from a scroll event's state object.
   * Use this in scroll handlers that already have distanceToBottom computed.
   *
   * @param {object} options
   * @param {boolean} options.fetchedOnce
   * @param {boolean} options.canLoadMoreFuture
   * @param {object} options.state - Scroll state with scroller and distanceToBottom
   * @param {number} [options.distanceThresholdPixels]
   */
  updatePendingContentFromScrollState(options) {
    const {
      scroller,
      fetchedOnce,
      canLoadMoreFuture,
      state,
      distanceThresholdPixels,
    } = options;

    this.#updateHasPendingContentBelow({
      scroller,
      fetchedOnce,
      canLoadMoreFuture,
      distanceToBottomPixels: state?.distanceToBottom?.pixels ?? 0,
      distanceThresholdPixels,
    });
  }

  /**
   * Update pending content state by reading current scroller position.
   * Use this when you need to recompute after a resize or similar event.
   *
   * @param {object} options
   * @param {HTMLElement | null} options.scroller
   * @param {boolean} options.fetchedOnce
   * @param {boolean} options.canLoadMoreFuture
   * @param {number} [options.distanceThresholdPixels]
   */
  updatePendingContentFromScrollerPosition(options) {
    const {
      scroller,
      fetchedOnce,
      canLoadMoreFuture,
      distanceThresholdPixels,
    } = options;

    if (!scroller) {
      this.hasPendingContentBelow = false;
      return;
    }

    const distanceToBottomPixels = -scroller.scrollTop;

    this.#updateHasPendingContentBelow({
      scroller,
      fetchedOnce,
      canLoadMoreFuture,
      distanceToBottomPixels,
      distanceThresholdPixels,
    });
  }

  /**
   * Callback for presence change events. Updates userIsPresent and
   * triggers onUserPresent callback when user returns.
   *
   * @param {boolean} present
   */
  @bind
  onPresenceChangeCallback(present) {
    this.userIsPresent = present;
    if (present) {
      this.#onUserPresent?.();
    }
  }

  /**
   * Handle an incoming message by either auto-scrolling or preserving viewport.
   *
   * If shouldAutoScroll is true, adds the message and scrolls to show it.
   * Otherwise, preserves the current scroll position and tracks the message as pending.
   *
   * @param {object} options
   * @param {HTMLElement | null} options.scroller - The scrollable container
   * @param {boolean} options.shouldAutoScroll - Whether to auto-scroll to the new message
   * @param {Function} options.addMessage - Function that adds the message to the list
   * @param {Function} [options.onAutoAdd] - Callback after auto-adding (e.g. to scroll)
   * @param {number} [options.messageCount=1] - Number of messages being added
   */
  handleIncomingMessage(options = {}) {
    const {
      scroller,
      shouldAutoScroll,
      addMessage,
      onAutoAdd,
      messageCount = 1,
    } = options;

    if (shouldAutoScroll) {
      addMessage?.();
      this.clearPendingMessages();
      onAutoAdd?.();
      return;
    }

    maintainScrollPosition(scroller, addMessage);
    this.addPendingMessages(messageCount);

    schedule("afterRender", () => {
      this.hasPendingContentBelow = this.#computeHasPendingContentBelow(
        scroller,
        false
      );
    });
  }

  /**
   * Compute whether there is pending content below the current scroll position.
   *
   * @param {HTMLElement | null} scroller
   * @param {boolean} isScrolledAway - Whether user is scrolled away from bottom
   * @returns {boolean}
   */
  #computeHasPendingContentBelow(scroller, isScrolledAway) {
    return (
      this.#canScroll(scroller) && (this.hasPendingMessages || isScrolledAway)
    );
  }

  /**
   * Add pending messages to the count for this context.
   *
   * @param {number} [count=1] - Number of messages to add
   */
  addPendingMessages(count = 1) {
    if (this.contextKey && count > 0) {
      this.chatPanePendingManager.add(this.contextKey, count);
    }
  }

  /**
   * Clear all pending messages for this context and reset pending content state.
   */
  clearPendingMessages() {
    if (this.contextKey) {
      this.chatPanePendingManager.clear(this.contextKey);
    }
    this.hasPendingContentBelow = false;
  }
}
