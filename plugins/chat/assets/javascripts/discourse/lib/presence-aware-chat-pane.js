import { tracked } from "@glimmer/tracking";
import { setOwner } from "@ember/owner";
import { schedule } from "@ember/runloop";
import { service } from "@ember/service";
import { bind } from "discourse/lib/decorators";
import userPresent, {
  onPresenceChange,
  removeOnPresenceChange,
} from "discourse/lib/user-presence";

const CHAT_PRESENCE_OPTIONS = {
  userUnseenTime: 1 * 60 * 1000,
  browserHiddenTime: 0,
};

/**
 * Shared state + helpers for chat panes (channel + thread).
 *
 * This is intentionally used via composition rather than inheritance so callers
 * can be explicit about which behaviors they're invoking.
 */
export default class PresenceAwareChatPane {
  @service chatPanePendingManager;

  @tracked userIsPresent = true;
  @tracked pendingMessageCount = 0;
  @tracked needsArrow = false;
  @tracked contextKey = null;

  /**
   * @type {(() => void) | null}
   */
  #onUserPresent = null;

  /**
   * @type {{ element: HTMLElement; scrollTop: number; scrollHeight: number } | null}
   */
  #pendingScrollAdjustment = null;

  /**
   * @param {object} owner - The Ember owner for DI
   * @param {object} options
   * @param {(() => void) | null} [options.onUserPresent]
   */
  constructor(owner, options = {}) {
    setOwner(this, owner);
    this.#onUserPresent = options.onUserPresent ?? null;
  }

  /**
   * Initialize presence tracking. Call from component setup.
   */
  setup() {
    this.userIsPresent = userPresent(CHAT_PRESENCE_OPTIONS);
    onPresenceChange({
      callback: this.onPresenceChangeCallback,
      ...CHAT_PRESENCE_OPTIONS,
    });
  }

  /**
   * Cleanup presence tracking. Call from component teardown.
   */
  teardown() {
    removeOnPresenceChange(this.onPresenceChangeCallback);
    this.resetPendingState();
  }

  /**
   * @returns {boolean}
   */
  get hasPendingNewMessages() {
    return this.pendingMessageCount > 0;
  }

  /**
   * @param {HTMLElement | null} scroller
   * @returns {boolean}
   */
  #canScroll(scroller) {
    if (!scroller) {
      return false;
    }

    // Use a small tolerance because `scrollHeight` and `clientHeight` can
    // occasionally differ by subpixel rounding.
    return scroller.scrollHeight - scroller.clientHeight > 1;
  }

  /**
   * Computes whether the arrow should be shown based on scroll position and
   * whether there are newer messages available to load.
   *
   * @param {object} options
   * @param {boolean} options.fetchedOnce
   * @param {boolean} options.canLoadMoreFuture
   * @param {number} options.distanceToBottomPixels
   * @param {number} [options.distanceThresholdPixels]
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
   * Updates `needsArrow` based on scroll position and loader state, while still
   * respecting pending message state and scrollability.
   *
   * @param {object} options
   * @param {HTMLElement | null} options.scroller
   * @param {boolean} options.fetchedOnce
   * @param {boolean} options.canLoadMoreFuture
   * @param {number} options.distanceToBottomPixels
   * @param {number} [options.distanceThresholdPixels]
   */
  #updateArrowVisibility(options) {
    const { scroller } = options;
    const isScrolledAway = this.#computeIsScrolledAway(options);
    this.needsArrow = this.#computeArrowVisibility(scroller, isScrolledAway);
  }

  /**
   * Convenience helper for scroll handlers that already computed `distanceToBottom`.
   *
   * @param {object} options
   * @param {boolean} options.fetchedOnce
   * @param {boolean} options.canLoadMoreFuture
   * @param {{ distanceToBottom?: { pixels: number } }} options.state
   * @param {number} [options.distanceThresholdPixels]
   */
  updateArrowVisibilityFromScrollState(options) {
    const { fetchedOnce, canLoadMoreFuture, state, distanceThresholdPixels } =
      options;

    this.#updateArrowVisibility({
      scroller: state?.scroller,
      fetchedOnce,
      canLoadMoreFuture,
      distanceToBottomPixels: state?.distanceToBottom?.pixels ?? 0,
      distanceThresholdPixels,
    });
  }

  /**
   * Convenience helper for cases where we need to recompute based on the current
   * scroller position (e.g. after a resize).
   *
   * @param {object} options
   * @param {HTMLElement | null} options.scroller
   * @param {boolean} options.fetchedOnce
   * @param {boolean} options.canLoadMoreFuture
   * @param {number} [options.distanceThresholdPixels]
   */
  updateArrowVisibilityFromScrollerPosition(options) {
    const {
      scroller,
      fetchedOnce,
      canLoadMoreFuture,
      distanceThresholdPixels,
    } = options;

    if (!scroller) {
      this.needsArrow = false;
      return;
    }

    const distanceToBottomPixels = -scroller.scrollTop;

    this.#updateArrowVisibility({
      scroller,
      fetchedOnce,
      canLoadMoreFuture,
      distanceToBottomPixels,
      distanceThresholdPixels,
    });
  }

  /**
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
   * Prevent viewport drift when the list grows while the user is scrolled away
   * from the bottom.
   *
   * Our chat scroller uses `flex-direction: column-reverse`, which gives us a
   * "bottom-origin" scroll. In this mode, appending content can change the
   * visible viewport unless we compensate for the height delta.
   *
   * @param {HTMLElement | null} scroller
   * @param {Function} callback
   */
  preserveViewportWhile(scroller, callback) {
    if (!scroller) {
      callback?.();
      return;
    }

    if (this.#pendingScrollAdjustment) {
      this.#pendingScrollAdjustment.scrollTop = scroller.scrollTop;
      callback?.();
      return;
    }

    const adjustment = {
      element: scroller,
      scrollTop: scroller.scrollTop,
      scrollHeight: scroller.scrollHeight,
    };

    this.#pendingScrollAdjustment = adjustment;
    callback?.();

    schedule("afterRender", () => {
      const state = this.#pendingScrollAdjustment;
      this.#pendingScrollAdjustment = null;

      if (!state?.element) {
        return;
      }

      const heightDiff = state.element.scrollHeight - state.scrollHeight;
      if (!heightDiff || heightDiff < 1) {
        return;
      }

      state.element.scrollTop = state.scrollTop - heightDiff;
    });
  }

  /**
   * @param {object} options
   * @param {HTMLElement | null} options.scroller
   * @param {boolean} options.shouldAutoScroll
   * @param {Function} options.addMessage
   * @param {Function} [options.onAutoAdd]
   * @param {number} [options.messageCount]
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
      this.resetPendingState();
      onAutoAdd?.();
      return;
    }

    this.preserveViewportWhile(scroller, addMessage);
    this.#incrementPending(messageCount);

    schedule("afterRender", () => {
      this.needsArrow = this.#computeArrowVisibility(scroller, false);
    });
  }

  /**
   * @param {HTMLElement | null} scroller
   * @param {boolean} isScrolledAway
   * @returns {boolean}
   */
  #computeArrowVisibility(scroller, isScrolledAway) {
    return (
      this.#canScroll(scroller) &&
      (this.hasPendingNewMessages || isScrolledAway)
    );
  }

  /**
   * Clears any pending message state and updates the global pending manager.
   */
  resetPendingState() {
    if (this.pendingMessageCount && this.contextKey) {
      this.chatPanePendingManager.decrement(
        this.contextKey,
        this.pendingMessageCount
      );
    }

    this.pendingMessageCount = 0;
  }

  /**
   * @param {number} count
   */
  #incrementPending(count) {
    if (!count || count < 0) {
      return;
    }

    this.pendingMessageCount += count;

    if (this.contextKey) {
      this.chatPanePendingManager.increment(this.contextKey, count);
    }
  }
}
