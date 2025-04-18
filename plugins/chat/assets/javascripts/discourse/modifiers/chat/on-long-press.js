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

    this.element.addEventListener("pointerdown", this.handlePointerDown);
  }

  @bind
  onCancel() {
    cancel(this.timeout);

    if (this.capabilities.touch) {
      this.element.removeEventListener("pointermove", this.onCancel);
      this.element.removeEventListener("pointerup", this.onCancel);
      this.element.removeEventListener("pointercancel", this.onCancel);

      // Release pointer capture if we have it
      if (this.pointerId !== undefined) {
        try {
          this.element.releasePointerCapture(this.pointerId);
          // eslint-disable-next-line no-unused-vars
        } catch (error) {
          // Handle case where pointer capture might be released already
        }
        this.pointerId = undefined;
      }
    }

    this.onLongPressCancel(this.element);
  }

  @bind
  handlePointerDown(event) {
    // Handle multi-touch
    if (event.isPrimary === false) {
      this.onCancel();
      return;
    }

    // Store pointerId for releasing capture later
    this.pointerId = event.pointerId;

    // Capture the pointer to ensure all events go to this element
    this.element.setPointerCapture(event.pointerId);

    this.onLongPressStart(this.element, event);

    this.element.addEventListener("pointermove", this.onCancel);
    this.element.addEventListener("pointerup", this.onCancel);
    this.element.addEventListener("pointercancel", this.onCancel);

    this.timeout = discourseLater(() => {
      if (this.isDestroying || this.isDestroyed) {
        return;
      }

      // Add one-time event handler to prevent default action
      this.element.addEventListener("pointerup", cancelEvent, {
        once: true,
      });

      this.onLongPressEnd(this.element, event);
    }, 400);
  }

  cleanup() {
    if (!this.enabled) {
      return;
    }

    // Remove the main pointerdown listener
    this.element.removeEventListener("pointerdown", this.handlePointerDown);

    this.onCancel();
  }
}
