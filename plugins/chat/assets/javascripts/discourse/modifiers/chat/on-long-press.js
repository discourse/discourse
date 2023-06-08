import Modifier from "ember-modifier";
import { registerDestructor } from "@ember/destroyable";
import { inject as service } from "@ember/service";
import { bind } from "discourse-common/utils/decorators";
import { cancel } from "@ember/runloop";
import discourseLater from "discourse-common/lib/later";

function cancelEvent(event) {
  event.stopPropagation();
  event.preventDefault();
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

    element.addEventListener("touchstart", this.handleTouchStart, {
      passive: false,
      capture: true,
    });
  }

  @bind
  onCancel() {
    cancel(this.timeout);

    this.element.removeEventListener("touchmove", this.onCancel, {
      capture: true,
    });
    this.element.removeEventListener("touchend", this.onCancel, {
      capture: true,
    });
    this.element.removeEventListener("touchcancel", this.onCancel, {
      capture: true,
    });

    this.onLongPressCancel(this.element);
  }

  @bind
  handleTouchStart(event) {
    if (event.touches.length > 1) {
      this.onCancel();
      return;
    }

    cancelEvent(event);

    this.onLongPressStart(this.element, event);

    this.element.addEventListener("touchmove", this.onCancel, {
      capture: true,
    });
    this.element.addEventListener("touchend", this.onCancel, {
      capture: true,
    });
    this.element.addEventListener("touchcancel", this.onCancel, {
      capture: true,
    });

    this.timeout = discourseLater(() => {
      if (this.isDestroying || this.isDestroyed) {
        return;
      }

      this.element.addEventListener("touchend", cancelEvent, {
        once: true,
        capture: true,
      });

      this.onLongPressEnd(this.element, event);
    }, 400);
  }

  cleanup() {
    if (!this.enabled) {
      return;
    }

    this.onCancel();
  }
}
