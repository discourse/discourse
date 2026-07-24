import Component from "@glimmer/component";
import { cancel, scheduleOnce } from "@ember/runloop";
import { service } from "@ember/service";
import discourseDebounce from "discourse/lib/debounce";
import { bind } from "discourse/lib/decorators";
import discourseLater from "discourse/lib/later";
import isZoomed from "discourse/lib/zoom-check";

const KEYBOARD_DETECT_THRESHOLD = 150;

// long enough for an async refocus to land; well under the OS hide animation
const FOCUS_SETTLE_MS = 100;

// ties a focus loss to the touch that caused it
const RECENT_TOUCH_MS = 500;

// how long the dismissing tap's synthesized click can lag the reflow
const GHOST_TAP_MS = 400;

// a release this far from the start is a drag, which synthesizes no click
const TAP_SLOP_PX = 8;

// covers the OS animation, its late report, and the resize debounce
const VIEWPORT_CONFIRM_MS = 800;

// a tap on these may hand focus back to an editable
const FOCUS_CAPABLE_SELECTOR =
  "a, button, input, textarea, select, summary, label, [contenteditable], [tabindex], [role='button']";

// input types that summon a soft keyboard, rather than a picker or nothing
const KEYBOARD_INPUT_TYPES = [
  "text",
  "search",
  "email",
  "url",
  "tel",
  "password",
  "number",
];

function isEditable(el) {
  return (
    el &&
    (el.isContentEditable ||
      el.matches("textarea") ||
      (el.matches("input") && KEYBOARD_INPUT_TYPES.includes(el.type)))
  );
}

export default class DVirtualHeight extends Component {
  @service site;
  @service capabilities;
  @service appEvents;

  #enabled = false;

  constructor() {
    super(...arguments);

    if (!window.visualViewport) {
      return;
    }

    if (!this.capabilities.isIpadOS && this.site.desktopView) {
      return;
    }

    this.#enabled = true;

    scheduleOnce("afterRender", this, this.debouncedOnViewportResize);

    window.visualViewport.addEventListener(
      "resize",
      this.debouncedOnViewportResize
    );

    this.appEvents.on("keyboard:will-hide", this, this.onKeyboardWillHide);
    document.addEventListener("focusout", this.onFocusOut);
    document.addEventListener("focusin", this.onFocusIn);
    document.addEventListener("touchstart", this.onTouchStart, {
      passive: true,
      capture: true,
    });
    document.addEventListener("touchend", this.onTouchEnd, {
      passive: true,
      capture: true,
    });
    document.addEventListener("touchcancel", this.onTouchCancel, {
      passive: true,
      capture: true,
    });
    // browser-chrome taps (e.g. the address bar) dismiss with no page event
    window.addEventListener("blur", this.onWindowBlur);
  }

  willDestroy() {
    super.willDestroy(...arguments);

    if (!this.#enabled) {
      return;
    }

    cancel(this.debouncedHandler);
    cancel(this.focusSettleHandler);
    cancel(this.showConfirmHandler);
    this.clearGhostTapSuppression?.();

    window.visualViewport.removeEventListener(
      "resize",
      this.debouncedOnViewportResize
    );

    this.appEvents.off("keyboard:will-hide", this, this.onKeyboardWillHide);
    document.removeEventListener("focusout", this.onFocusOut);
    document.removeEventListener("focusin", this.onFocusIn);
    document.removeEventListener("touchstart", this.onTouchStart, {
      capture: true,
    });
    document.removeEventListener("touchend", this.onTouchEnd, {
      capture: true,
    });
    document.removeEventListener("touchcancel", this.onTouchCancel, {
      capture: true,
    });
    window.removeEventListener("blur", this.onWindowBlur);
  }

  @bind
  onTouchStart(event) {
    // a click that follows a new touch is that tap's own, not a ghost
    this.clearGhostTapSuppression?.();

    const touch = event.touches?.[0];
    this.lastTouch = {
      at: Date.now(),
      x: touch?.clientX ?? 0,
      y: touch?.clientY ?? 0,
      moved: false,
      inert:
        event.target instanceof Element &&
        !event.target.closest(FOCUS_CAPABLE_SELECTOR),
    };
  }

  @bind
  onTouchEnd(event) {
    const touch = event.changedTouches?.[0];
    if (!this.lastTouch || !touch) {
      return;
    }

    this.lastTouch.at = Date.now();
    this.lastTouch.moved ||=
      Math.hypot(
        touch.clientX - this.lastTouch.x,
        touch.clientY - this.lastTouch.y
      ) > TAP_SLOP_PX;
  }

  @bind
  onTouchCancel() {
    // a cancelled touch is not a tap and synthesizes no click
    if (this.lastTouch) {
      this.lastTouch.moved = true;
    }
  }

  @bind
  onWindowBlur() {
    cancel(this.focusSettleHandler);
    this.onKeyboardWillHide();
  }

  @bind
  onFocusOut() {
    if (!document.documentElement.classList.contains("keyboard-visible")) {
      return;
    }

    cancel(this.focusSettleHandler);

    if (this.#focusLostToInertTouch()) {
      this.onKeyboardWillHide();

      // the tap's synthesized click would land on controls the reflow just
      // moved; drags synthesize none
      if (!this.lastTouch.moved) {
        this.#suppressGhostTap();
      }
      return;
    }

    this.focusSettleHandler = discourseDebounce(
      this,
      this.onFocusSettled,
      FOCUS_SETTLE_MS
    );
  }

  #focusLostToInertTouch() {
    const touch = this.lastTouch;
    return touch?.inert && Date.now() - touch.at < RECENT_TOUCH_MS;
  }

  #suppressGhostTap() {
    this.clearGhostTapSuppression?.();

    const swallow = (event) => {
      event.preventDefault();
      event.stopPropagation();
      this.clearGhostTapSuppression();
    };

    const timer = discourseLater(
      () => this.clearGhostTapSuppression(),
      GHOST_TAP_MS
    );

    this.clearGhostTapSuppression = () => {
      cancel(timer);
      document.removeEventListener("click", swallow, { capture: true });
      this.clearGhostTapSuppression = null;
    };

    document.addEventListener("click", swallow, { capture: true });
  }

  onFocusSettled() {
    if (!isEditable(document.activeElement)) {
      this.onKeyboardWillHide();
    }
  }

  // reflow immediately instead of waiting for the visualViewport resize,
  // which only fires after the OS hide animation
  onKeyboardWillHide() {
    const docEl = document.documentElement;

    if (!docEl.classList.contains("keyboard-visible") || isZoomed()) {
      return;
    }

    cancel(this.debouncedHandler);
    cancel(this.showConfirmHandler);

    this.lastKeyboardHeight = this.previousHeight;
    this.pendingHide = {
      at: Date.now(),
      composerVh: docEl.style.getPropertyValue("--composer-vh"),
      height: this.previousHeight,
    };

    this.previousHeight = Math.round(window.innerHeight);
    docEl.style.setProperty("--composer-vh", `${this.previousHeight / 100}px`);

    this.appEvents.trigger("keyboard-visibility-change", false);
    docEl.classList.remove("keyboard-visible");
  }

  @bind
  onFocusIn(event) {
    const docEl = document.documentElement;

    if (
      !isEditable(event.target) ||
      docEl.classList.contains("keyboard-visible") ||
      isZoomed()
    ) {
      return;
    }

    cancel(this.focusSettleHandler);

    // a refocus mid-hide cancels the OS animation, and the unchanged
    // viewport never reports back — restore the interrupted state
    const pending = this.pendingHide;
    if (pending && Date.now() - pending.at <= VIEWPORT_CONFIRM_MS) {
      this.pendingHide = null;
      this.#showKeyboardState(pending.height, pending.composerVh);
      this.#armShowConfirm();
      return;
    }

    // the keyboard only reports after its show animation; apply the last
    // known keyboard height now and revert if the viewport never confirms
    if (this.lastKeyboardHeight) {
      this.#showKeyboardState(this.lastKeyboardHeight);
      this.#armShowConfirm();
    }
  }

  #showKeyboardState(height, composerVh = `${height / 100}px`) {
    this.previousHeight = height;
    document.documentElement.style.setProperty("--composer-vh", composerVh);

    this.appEvents.trigger("keyboard-visibility-change", true);
    document.documentElement.classList.add("keyboard-visible");
  }

  #armShowConfirm() {
    cancel(this.showConfirmHandler);
    this.showConfirmHandler = discourseLater(
      this,
      this.revertUnconfirmedShow,
      VIEWPORT_CONFIRM_MS
    );
  }

  revertUnconfirmedShow() {
    // a cancelled hide leaves the viewport unchanged with nothing to
    // report; check the geometry directly
    if (
      window.innerHeight - window.visualViewport.height >
      KEYBOARD_DETECT_THRESHOLD
    ) {
      return;
    }

    this.onKeyboardWillHide();

    // no keyboard came (e.g. a hardware keyboard); stop predicting until a
    // real one is observed again
    this.lastKeyboardHeight = null;
    this.pendingHide = null;
  }

  setVH() {
    if (isZoomed()) {
      return;
    }

    const height = Math.round(window.visualViewport.height);

    if (this.previousHeight && Math.abs(this.previousHeight - height) <= 1) {
      return false;
    }

    this.previousHeight = height;

    document.documentElement.style.setProperty(
      "--composer-vh",
      `${height / 100}px`
    );
  }

  @bind
  debouncedOnViewportResize() {
    this.debouncedHandler = discourseDebounce(this, this.onViewportResize, 50);
  }

  @bind
  onViewportResize() {
    this.pendingHide = null;
    cancel(this.showConfirmHandler);

    const setVHresult = this.setVH();

    if (setVHresult === false) {
      return;
    }

    const docEl = document.documentElement;

    let keyboardVisible = false;

    let viewportWindowDiff = window.innerHeight - window.visualViewport.height;

    if (viewportWindowDiff > KEYBOARD_DETECT_THRESHOLD) {
      keyboardVisible = true;
      this.lastKeyboardHeight = this.previousHeight;
    }

    this.appEvents.trigger("keyboard-visibility-change", keyboardVisible);

    keyboardVisible
      ? docEl.classList.add("keyboard-visible")
      : docEl.classList.remove("keyboard-visible");
  }
}
