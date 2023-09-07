import Component from "@glimmer/component";
import { action } from "@ember/object";
import { emojiUnescape, emojiUrlFor } from "discourse/lib/text";
import { cancel } from "@ember/runloop";
import { inject as service } from "@ember/service";
import setupPopover from "discourse/lib/d-popover";
import discourseLater from "discourse-common/lib/later";
import { tracked } from "@glimmer/tracking";
import { getReactionText } from "discourse/plugins/chat/discourse/lib/get-reaction-text";

export default class ChatMessageReaction extends Component {
  @service capabilities;
  @service currentUser;

  @tracked isActive = false;

  get showCount() {
    return this.args.showCount ?? true;
  }

  @action
  setup(element) {
    this.setupListeners(element);
    this.setupTooltip(element);
  }

  @action
  teardown() {
    cancel(this.longPressHandler);
    this.teardownTooltip();
  }

  @action
  setupListeners(element) {
    this.element = element;

    if (this.capabilities.touch) {
      this.element.addEventListener("touchstart", this.onTouchStart, {
        passive: true,
      });
      this.element.addEventListener("touchmove", this.cancelTouch, {
        passive: true,
      });
      this.element.addEventListener("touchend", this.onTouchEnd);
      this.element.addEventListener("touchCancel", this.cancelTouch);
    }

    this.element.addEventListener("click", this.handleClick, {
      passive: true,
    });
  }

  @action
  teardownListeners() {
    if (this.capabilities.touch) {
      this.element.removeEventListener("touchstart", this.onTouchStart, {
        passive: true,
      });
      this.element.removeEventListener("touchmove", this.cancelTouch, {
        passive: true,
      });
      this.element.removeEventListener("touchend", this.onTouchEnd);
      this.element.removeEventListener("touchCancel", this.cancelTouch);
    }

    this.element.removeEventListener("click", this.handleClick, {
      passive: true,
    });
  }

  @action
  onTouchStart(event) {
    event.stopPropagation();
    this.isActive = true;

    this.longPressHandler = discourseLater(() => {
      this.touching = false;
    }, 400);

    this.touching = true;
  }

  @action
  cancelTouch() {
    cancel(this.longPressHandler);
    this._tippyInstance?.hide();
    this.touching = false;
    this.isActive = false;
  }

  @action
  onTouchEnd(event) {
    event.preventDefault();

    if (this.touching) {
      this.handleClick(event);
    }

    cancel(this.longPressHandler);
    this._tippyInstance?.hide();
    this.isActive = false;
  }

  @action
  setupTooltip(element) {
    this._tippyInstance = setupPopover(element, {
      trigger: "mouseenter",
      interactive: false,
      allowHTML: true,
      offset: [0, 10],
      onShow(instance) {
        if (instance.props.content === "") {
          return false;
        }
      },
    });
  }

  @action
  teardownTooltip() {
    this._tippyInstance?.destroy();
  }

  @action
  refreshTooltip() {
    this._tippyInstance?.setContent(this.popoverContent || "");
  }

  get emojiString() {
    return `:${this.args.reaction.emoji}:`;
  }

  get emojiUrl() {
    return emojiUrlFor(this.args.reaction.emoji);
  }

  @action
  handleClick(event) {
    event.stopPropagation();

    this.args.onReaction?.(
      this.args.reaction.emoji,
      this.args.reaction.reacted ? "remove" : "add"
    );

    this._tippyInstance?.clearDelayTimeouts();
  }

  get popoverContent() {
    if (!this.args.reaction.count || !this.args.reaction.users?.length) {
      return;
    }

    return emojiUnescape(getReactionText(this.args.reaction, this.currentUser));
  }
}
