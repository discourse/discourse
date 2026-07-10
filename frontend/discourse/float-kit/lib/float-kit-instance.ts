import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import { cancel } from "@ember/runloop";
import { service } from "@ember/service";
import type {
  FloatKitTrigger,
  TooltipOptions,
} from "discourse/float-kit/lib/constants";
import { bind } from "discourse/lib/decorators";
import { makeArray } from "discourse/lib/helpers";
import discourseLater from "discourse/lib/later";
import type Site from "discourse/models/site";

const TOUCH_OPTIONS = { passive: true, capture: true } as const;

function cancelEvent(event: Event) {
  event.preventDefault();
  event.stopImmediatePropagation();
}

/**
 * The behavior shared by every anchored float (menus and tooltips): the trigger's
 * event listeners, the touch/hover trigger handling, and the `show`/`close`
 * lifecycle hooks. Subclasses supply the concrete state and actions this base
 * orchestrates (`options`, `trigger`, `expanded`, and the trigger/pointer actions).
 */
export default abstract class FloatKitInstance {
  @service declare site: Site;

  @tracked id: string | null = null;

  /** The merged options bag; a menu or tooltip subclass narrows the exact shape. */
  abstract options: TooltipOptions;

  /**
   * The reference the float is anchored to — a real element, or a virtual one when the
   * float is positioned programmatically. Use `triggerElement` for element-only work.
   */
  abstract trigger: FloatKitTrigger;

  /** Whether the float is currently open. */
  abstract expanded: boolean;

  /** The rendered float body, assigned by the `apply-floating-ui` modifier. */
  declare content: HTMLElement;

  declare touchTimeout: ReturnType<typeof discourseLater>;

  declare delayedHoverTimeout: ReturnType<typeof discourseLater>;

  declare openedByDelayedHover: boolean;

  declare isDestroying?: boolean;

  declare isDestroyed?: boolean;

  /**
   * The trigger narrowed to a real element, or `null` when it is a virtual reference.
   * The listener, focus, and containment logic all go through this so a virtual trigger
   * is a no-op rather than a runtime error.
   */
  get triggerElement(): HTMLElement | null {
    return this.trigger instanceof HTMLElement ? this.trigger : null;
  }

  /** The element the rendered float body is portalled into. */
  abstract get portalOutletElement(): HTMLElement | null;

  abstract onClick(event: MouseEvent): Promise<void>;
  abstract onPointerMove(event: PointerEvent): Promise<void>;
  abstract onPointerLeave(event: PointerEvent): Promise<void>;
  abstract onTrigger(event?: Event): Promise<void>;

  @action
  async show() {
    await this.options.onShow?.();
  }

  @action
  // `options` is part of the shared close contract (a menu uses it to decide whether to
  // refocus its trigger); the base close has no trigger to refocus, so it ignores it.
  // eslint-disable-next-line @typescript-eslint/no-unused-vars
  async close(options?: { focusTrigger?: boolean }) {
    await this.options.onClose?.();
  }

  @action
  async onFocus(event: FocusEvent) {
    await this.onTrigger(event);
  }

  @action
  async onBlur(event: FocusEvent) {
    await this.onTrigger(event);
  }

  @action
  async onFocusIn(event: FocusEvent) {
    await this.onTrigger(event);
  }

  @action
  async onFocusOut(event: FocusEvent) {
    await this.onTrigger(event);
  }

  @action
  trapPointerDown(event: PointerEvent) {
    // this is done to avoid trigger on click outside when you click on your own trigger
    // given trigger and content are not in the same div, we can't just check if target is
    // inside the menu
    if (this.shouldTrapPointerDown) {
      event.stopPropagation();
    }
  }

  @action
  onTouchStart(event: TouchEvent) {
    if (event.touches.length > 1) {
      this.onTouchCancel();
      return;
    }

    event.stopPropagation();

    const element = this.triggerElement;
    if (!element) {
      return;
    }

    element.addEventListener("touchmove", this.onTouchCancel, TOUCH_OPTIONS);
    element.addEventListener("touchcancel", this.onTouchCancel, TOUCH_OPTIONS);
    element.addEventListener("touchend", this.onTouchCancel, TOUCH_OPTIONS);
    this.touchTimeout = discourseLater(() => {
      if (this.isDestroying || this.isDestroyed) {
        return;
      }

      element.addEventListener("touchend", cancelEvent, {
        once: true,
        capture: true,
      });

      this.onTrigger(event);
    }, 500);
  }

  @action
  onDelayedHoverEnter(event: PointerEvent) {
    cancel(this.delayedHoverTimeout);
    this.delayedHoverTimeout = discourseLater(() => {
      if (this.expanded) {
        return;
      }
      this.openedByDelayedHover = true;
      this.onTrigger(event);
    }, 250);
  }

  @action
  onDelayedHoverLeave() {
    cancel(this.delayedHoverTimeout);
  }

  @bind
  onTouchCancel() {
    cancel(this.touchTimeout);

    const element = this.triggerElement;
    if (!element) {
      return;
    }

    element.removeEventListener("touchmove", this.onTouchCancel);
    element.removeEventListener("touchend", this.onTouchCancel);
    element.removeEventListener("touchcancel", this.onTouchCancel);
  }

  tearDownListeners() {
    const element = this.triggerElement;
    if (element) {
      element.removeEventListener("pointerdown", this.trapPointerDown);
    }

    if (!this.options?.listeners || !element) {
      return;
    }

    makeArray(this.triggers)
      .filter(Boolean)
      .forEach((trigger) => {
        switch (trigger) {
          case "hold":
            element.removeEventListener("touchstart", this.onTouchStart);
            break;
          case "focus":
            element.removeEventListener("focus", this.onFocus);
            element.removeEventListener("blur", this.onBlur);
            break;
          case "focusin":
            element.removeEventListener("focusin", this.onFocusIn);
            element.removeEventListener("focusout", this.onFocusOut);
            break;
          case "hover":
            element.removeEventListener("pointermove", this.onPointerMove);
            if (!this.options.interactive) {
              element.removeEventListener("pointerleave", this.onPointerLeave);
            }

            break;
          case "delayed-hover":
            cancel(this.delayedHoverTimeout);
            element.removeEventListener(
              "pointerenter",
              this.onDelayedHoverEnter
            );
            element.removeEventListener(
              "pointerleave",
              this.onDelayedHoverLeave
            );
            break;
          case "click":
            element.removeEventListener("click", this.onClick);
            break;
        }
      });

    cancel(this.touchTimeout);
  }

  setupListeners() {
    const element = this.triggerElement;
    if (element) {
      element.addEventListener("pointerdown", this.trapPointerDown);
    }

    if (!this.options?.listeners || !element) {
      return;
    }

    makeArray(this.triggers)
      .filter(Boolean)
      .forEach((trigger) => {
        switch (trigger) {
          case "hold":
            element.addEventListener(
              "touchstart",
              this.onTouchStart,
              TOUCH_OPTIONS
            );
            break;
          case "focus":
            element.addEventListener("focus", this.onFocus, {
              passive: true,
            });
            element.addEventListener("blur", this.onBlur, {
              passive: true,
            });
            break;
          case "focusin":
            element.addEventListener("focusin", this.onFocusIn, {
              passive: true,
            });
            element.addEventListener("focusout", this.onFocusOut, {
              passive: true,
            });
            break;
          case "hover":
            element.addEventListener("pointermove", this.onPointerMove, {
              passive: true,
            });
            if (!this.options.interactive) {
              element.addEventListener("pointerleave", this.onPointerLeave, {
                passive: true,
              });
            }

            break;
          case "delayed-hover":
            element.addEventListener("pointerenter", this.onDelayedHoverEnter, {
              passive: true,
            });
            element.addEventListener("pointerleave", this.onDelayedHoverLeave, {
              passive: true,
            });
            break;
          case "click":
            element.addEventListener("click", this.onClick, {
              passive: true,
            });
            break;
        }
      });
  }

  get triggers(): string[] {
    const triggers = this.options.triggers;

    if (typeof triggers === "object" && !Array.isArray(triggers)) {
      return this.site.mobileView
        ? (triggers.mobile ?? ["click"])
        : (triggers.desktop ?? ["click"]);
    }

    return triggers ?? ["click"];
  }

  get untriggers(): string[] {
    const untriggers = this.options.untriggers;

    if (typeof untriggers === "object" && !Array.isArray(untriggers)) {
      return this.site.mobileView
        ? (untriggers.mobile ?? ["click"])
        : (untriggers.desktop ?? ["click"]);
    }

    return untriggers ?? ["click"];
  }

  get shouldTrapPointerDown() {
    return true;
  }
}
