import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import { next, schedule } from "@ember/runloop";
import { service } from "@ember/service";
import { bind } from "discourse/lib/decorators";

export const CHAT_PRESENCE_OPTIONS = {
  userUnseenTime: 10 * 60 * 1000,
  browserHiddenTime: 0,
};

export default class PresenceAwareChatPane extends Component {
  @service chatPanePendingManager;

  @tracked userIsPresent = true;
  @tracked pendingMessageCount = 0;
  @tracked needsArrow = false;

  scroller = null;
  _pendingScrollAdjustment = null;

  willDestroy() {
    super.willDestroy(...arguments);
    this.resetPendingState();
  }

  get pendingContextKey() {
    return null;
  }

  get hasPendingNewMessages() {
    return this.pendingMessageCount > 0;
  }

  @action
  registerScroller(element) {
    this.scroller = element;
  }

  @bind
  onPresenceChangeCallback(present) {
    this.userIsPresent = present;
    if (present) {
      this.debouncedUpdateLastReadMessage();
    }
  }

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

    next(() => {
      schedule("afterRender", () => {
        // this code causes a bit of a flash, we probably want to find a better way
        // it is important cause we want to keep the positio where it was when new chat messages arrive.
        // otherwise stuff drift, but there may be a much better way to achieve this.
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
    });
  }

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

  computeArrowVisibility(baseCondition) {
    return this.hasPendingNewMessages || baseCondition;
  }

  resetPendingState() {
    if (this.pendingMessageCount && this.pendingContextKey) {
      this.chatPanePendingManager.decrement(
        this.pendingContextKey,
        this.pendingMessageCount
      );
    }

    this.pendingMessageCount = 0;
  }

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
