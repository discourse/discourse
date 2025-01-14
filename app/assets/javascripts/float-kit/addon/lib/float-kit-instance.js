import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import { cancel } from "@ember/runloop";
import { service } from "@ember/service";
import { bind } from "discourse/lib/decorators";
import { makeArray } from "discourse/lib/helpers";
import discourseLater from "discourse/lib/later";

const TOUCH_OPTIONS = { passive: true, capture: true };

function cancelEvent(event) {
  event.preventDefault();
  event.stopImmediatePropagation();
}

export default class FloatKitInstance {
  @service site;

  @tracked id = null;

  @action
  async show() {
    await this.options.onShow?.();
  }

  @action
  async close() {
    await this.options.onClose?.();
  }

  @action
  async onFocus(event) {
    await this.onTrigger(event);
  }

  @action
  async onBlur(event) {
    await this.onTrigger(event);
  }

  @action
  async onFocusIn(event) {
    await this.onTrigger(event);
  }

  @action
  async onFocusOut(event) {
    await this.onTrigger(event);
  }

  @action
  trapPointerDown(event) {
    // this is done to avoid trigger on click outside when you click on your own trigger
    // given trigger and content are not in the same div, we can't just check if target is
    // inside the menu
    event.stopPropagation();
  }

  @action
  onTouchStart(event) {
    if (event.touches.length > 1) {
      this.onTouchCancel();
      return;
    }

    event.stopPropagation();

    this.trigger.addEventListener(
      "touchmove",
      this.onTouchCancel,
      TOUCH_OPTIONS
    );
    this.trigger.addEventListener(
      "touchcancel",
      this.onTouchCancel,
      TOUCH_OPTIONS
    );
    this.trigger.addEventListener(
      "touchend",
      this.onTouchCancel,
      TOUCH_OPTIONS
    );
    this.touchTimeout = discourseLater(() => {
      if (this.isDestroying || this.isDestroyed) {
        return;
      }

      this.trigger.addEventListener("touchend", cancelEvent, {
        once: true,
        capture: true,
      });

      this.onTrigger(event);
    }, 500);
  }

  @bind
  onTouchCancel() {
    cancel(this.touchTimeout);

    this.trigger.removeEventListener("touchmove", this.onTouchCancel);
    this.trigger.removeEventListener("touchend", this.onTouchCancel);
    this.trigger.removeEventListener("touchcancel", this.onTouchCancel);
  }

  tearDownListeners() {
    if (typeof this.trigger.addEventListener === "function") {
      this.trigger.removeEventListener("pointerdown", this.trapPointerDown);
    }

    if (!this.options?.listeners) {
      return;
    }

    makeArray(this.triggers)
      .filter(Boolean)
      .forEach((trigger) => {
        switch (trigger) {
          case "hold":
            this.trigger.addEventListener("touchstart", this.onTouchStart);
            break;
          case "focus":
            this.trigger.removeEventListener("focus", this.onFocus);
            this.trigger.removeEventListener("blur", this.onBlur);
            break;
          case "focusin":
            this.trigger.removeEventListener("focusin", this.onFocusIn);
            this.trigger.removeEventListener("focusout", this.onFocusOut);
            break;
          case "hover":
            this.trigger.removeEventListener("mousemove", this.onMouseMove);
            if (!this.options.interactive) {
              this.trigger.removeEventListener("mouseleave", this.onMouseLeave);
            }

            break;
          case "click":
            this.trigger.removeEventListener("click", this.onClick);
            break;
        }
      });

    cancel(this.touchTimeout);
  }

  setupListeners() {
    if (typeof this.trigger.addEventListener === "function") {
      this.trigger.addEventListener("pointerdown", this.trapPointerDown);
    }

    if (!this.options?.listeners) {
      return;
    }

    makeArray(this.triggers)
      .filter(Boolean)
      .forEach((trigger) => {
        switch (trigger) {
          case "hold":
            this.trigger.addEventListener(
              "touchstart",
              this.onTouchStart,
              TOUCH_OPTIONS
            );
            break;
          case "focus":
            this.trigger.addEventListener("focus", this.onFocus, {
              passive: true,
            });
            this.trigger.addEventListener("blur", this.onBlur, {
              passive: true,
            });
            break;
          case "focusin":
            this.trigger.addEventListener("focusin", this.onFocusIn, {
              passive: true,
            });
            this.trigger.addEventListener("focusout", this.onFocusOut, {
              passive: true,
            });
            break;
          case "hover":
            this.trigger.addEventListener("mousemove", this.onMouseMove, {
              passive: true,
            });
            if (!this.options.interactive) {
              this.trigger.addEventListener("mouseleave", this.onMouseLeave, {
                passive: true,
              });
            }

            break;
          case "click":
            this.trigger.addEventListener("click", this.onClick, {
              passive: true,
            });
            break;
        }
      });
  }

  get triggers() {
    if (
      typeof this.options.triggers === "object" &&
      !Array.isArray(this.options.triggers)
    ) {
      return this.site.mobileView
        ? this.options.triggers.mobile ?? ["click"]
        : this.options.triggers.desktop ?? ["click"];
    }

    return this.options.triggers ?? ["click"];
  }

  get untriggers() {
    if (
      typeof this.options.untriggers === "object" &&
      !Array.isArray(this.options.untriggers)
    ) {
      return this.site.mobileView
        ? this.options.untriggers.mobile ?? ["click"]
        : this.options.untriggers.desktop ?? ["click"];
    }

    return this.options.untriggers ?? ["click"];
  }
}
