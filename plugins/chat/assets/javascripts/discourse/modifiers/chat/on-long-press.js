import { registerDestructor } from "@ember/destroyable";
import { cancel } from "@ember/runloop";
import { service } from "@ember/service";
import Modifier from "ember-modifier";
import { bind } from "discourse/lib/decorators";
import discourseLater from "discourse/lib/later";

function cancelEvent(event) {
  event.stopPropagation();
}

export default class ChatOnLongPress extends Modifier {
  @service capabilities;
  @service site;

  constructor(owner, args) {
    super(owner, args);
    registerDestructor(this, (instance) => instance.cleanup());
  }

  get enabled() {
    return this.capabilities.touch && this.site.mobileView;
  }

  modify(element, [onLongPressStart, onLongPressEnd, onLongPressCancel]) {
    if (!this.enabled) {
      return;
    }

    this.element = element;
    this.onLongPressStart = onLongPressStart || (() => {});
    this.onLongPressEnd = onLongPressEnd || (() => {});
    this.onLongPressCancel = onLongPressCancel || (() => {});

    this.element.addEventListener("touchstart", this.handleTouchStart, {
      passive: true,
    });
  }

  @bind
  onCancel() {
    cancel(this.timeout);

    if (this.capabilities.touch) {
      this.element.removeEventListener("touchmove", this.onCancel, {
        passive: true,
      });
      this.element.removeEventListener("touchend", this.onCancel);
      this.element.removeEventListener("touchcancel", this.onCancel);
    }

    this.onLongPressCancel(this.element);
  }

  @bind
  handleTouchStart(event) {
    if (event.touches.length > 1) {
      this.onCancel();
      return;
    }
    this.onLongPressStart(this.element, event);
    this.element.addEventListener("touchmove", this.onCancel, {
      passive: true,
    });
    this.element.addEventListener("touchend", this.onCancel);
    this.element.addEventListener("touchcancel", this.onCancel);
    this.timeout = discourseLater(() => {
      if (this.isDestroying || this.isDestroyed) {
        return;
      }

      this.element.addEventListener("touchend", cancelEvent, {
        once: true,
        passive: true,
      });

      this.onLongPressEnd(this.element, event);
    }, 400);
  }

  cleanup() {
    if (!this.enabled) {
      return;
    }

    this.element.removeEventListener("touchstart", this.handleTouchStart, {
      passive: true,
    });

    this.onCancel();
  }
}
