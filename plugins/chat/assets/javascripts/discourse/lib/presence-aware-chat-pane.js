import { tracked } from "@glimmer/tracking";
import { schedule } from "@ember/runloop";
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
 * can be explicit about which behaviors they’re invoking.
 */
export default class PresenceAwareChatPane {
  @tracked userIsPresent = true;
  @tracked pendingMessageCount = 0;
  @tracked needsArrow = false;

  /**
   * @type {HTMLElement | null}
   */
  scroller = null;

  /**
   * @type {import("discourse/plugins/chat/discourse/services/chat-pane-pending-manager").default}
   */
  chatPanePendingManager;
  /**
   * @type {() => (string | null)}
   */
  getPendingContextKey;
  /**
   * @type {(() => void) | null}
   */
  onUserPresent;
  /**
   * @type {{ element: HTMLElement; scrollTop: number; scrollHeight: number } | null}
   */
  _pendingScrollAdjustment = null;

  /**
   * @param {object} options
   * @param {import("discourse/plugins/chat/discourse/services/chat-pane-pending-manager").default} options.chatPanePendingManager
   * @param {() => (string | null)} options.getPendingContextKey
   * @param {(() => void) | null} [options.onUserPresent]
   */
  constructor(options) {
    this.chatPanePendingManager = options.chatPanePendingManager;
    this.getPendingContextKey = options.getPendingContextKey;
    this.onUserPresent = options.onUserPresent ?? null;
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
   * @returns {string | null}
   */
  get pendingContextKey() {
    return this.getPendingContextKey?.() ?? null;
  }

  /**
   * @returns {boolean}
   */
  get hasPendingNewMessages() {
    return this.pendingMessageCount > 0;
  }

  /**
   * @param {HTMLElement} element
   */
  @bind
  registerScroller(element) {
    this.scroller = element;
  }

  /**
   * @param {boolean} present
   */
  @bind
  onPresenceChangeCallback(present) {
    this.userIsPresent = present;
    if (present) {
      this.onUserPresent?.();
    }
  }

  /**
   * Prevent viewport drift when the list grows while the user is scrolled away
   * from the bottom.
   *
   * Our chat scroller uses `flex-direction: column-reverse`, which gives us a
   * “bottom-origin” scroll. In this mode, appending content can change the
   * visible viewport unless we compensate for the height delta.
   *
   * @param {Function} callback
   */
  preserveViewportWhile(callback) {
    if (!this.scroller) {
      callback?.();
      return;
    }

    const scroller = this.scroller;

    if (this._pendingScrollAdjustment) {
      this._pendingScrollAdjustment.scrollTop = scroller.scrollTop;
      callback?.();
      return;
    }

    const adjustment = {
      element: scroller,
      scrollTop: scroller.scrollTop,
      scrollHeight: scroller.scrollHeight,
    };

    this._pendingScrollAdjustment = adjustment;
    callback?.();

    schedule("afterRender", () => {
      const state = this._pendingScrollAdjustment;
      this._pendingScrollAdjustment = null;

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
   * @param {boolean} options.shouldAutoScroll
   * @param {Function} options.addMessage
   * @param {Function} [options.onAutoAdd]
   * @param {number} [options.messageCount]
   */
  handleIncomingMessage(options = {}) {
    const {
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

    this.preserveViewportWhile(addMessage);
    this.#incrementPending(messageCount);
    this.needsArrow = true;
  }

  /**
   * @param {boolean} baseCondition
   * @returns {boolean}
   */
  computeArrowVisibility(baseCondition) {
    return this.hasPendingNewMessages || baseCondition;
  }

  /**
   * Clears any pending message state and updates the global pending manager.
   */
  resetPendingState() {
    if (this.pendingMessageCount && this.pendingContextKey) {
      this.chatPanePendingManager.decrement(
        this.pendingContextKey,
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

    if (this.pendingContextKey) {
      this.chatPanePendingManager.increment(this.pendingContextKey, count);
    }
  }
}
