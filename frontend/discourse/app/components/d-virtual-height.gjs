import Component from "@glimmer/component";
import { cancel, scheduleOnce } from "@ember/runloop";
import { service } from "@ember/service";
import discourseDebounce from "discourse/lib/debounce";
import { bind } from "discourse/lib/decorators";
import discourseLater from "discourse/lib/later";
import isZoomed from "discourse/lib/zoom-check";

const KEYBOARD_DETECT_THRESHOLD = 150;

// long enough for an async refocus (e.g. a dropdown autofocusing its search
// input) to land; well under the OS hide animation
const FOCUS_SETTLE_MS = 100;

// ties a focus loss to the touch that caused it
const RECENT_TOUCH_MS = 500;

// how long the dismissing tap's synthesized click can lag the reflow
const GHOST_TAP_MS = 400;

// a release this far from the start is a drag, which synthesizes no click
const TAP_SLOP_PX = 8;

// an early reflow is provisional this long: a refocus within it cancels the
// OS hide mid-animation, and the unchanged viewport never reports back
const HIDE_CONFIRM_MS = 700;

// a tap on these may hand focus back to an editable, so it can't be
// trusted as a keyboard dismiss
const FOCUS_CAPABLE_SELECTOR =
  "a, button, input, textarea, select, summary, label, [contenteditable], [tabindex], [role='button']";

function isEditable(el) {
  return el && (el.matches("input, textarea, select") || el.isContentEditable);
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
    window.removeEventListener("blur", this.onWindowBlur);
  }

  @bind
  onTouchStart(event) {
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
  onWindowBlur() {
    cancel(this.focusSettleHandler);
    this.onKeyboardWillHide();
  }

  // once focus settles outside any editable, the keyboard can't stay up
  @bind
  onFocusOut() {
    if (!document.documentElement.classList.contains("keyboard-visible")) {
      return;
    }

    cancel(this.focusSettleHandler);

    if (this.#focusLostToInertTouch()) {
      this.onKeyboardWillHide();

      // a tap's synthesized click would land on controls the reflow just
      // moved under the finger; drags synthesize none
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
    const pending = this.pendingHide;

    if (
      !pending ||
      Date.now() - pending.at > HIDE_CONFIRM_MS ||
      !isEditable(event.target)
    ) {
      return;
    }

    this.pendingHide = null;
    cancel(this.focusSettleHandler);

    this.previousHeight = pending.height;
    document.documentElement.style.setProperty(
      "--composer-vh",
      pending.composerVh
    );

    this.appEvents.trigger("keyboard-visibility-change", true);
    document.documentElement.classList.add("keyboard-visible");
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
    // the viewport speaking is the source of truth again
    this.pendingHide = null;

    const setVHresult = this.setVH();

    if (setVHresult === false) {
      return;
    }

    const docEl = document.documentElement;

    let keyboardVisible = false;

    let viewportWindowDiff = window.innerHeight - window.visualViewport.height;

    if (viewportWindowDiff > KEYBOARD_DETECT_THRESHOLD) {
      keyboardVisible = true;
    }

    this.appEvents.trigger("keyboard-visibility-change", keyboardVisible);

    keyboardVisible
      ? docEl.classList.add("keyboard-visible")
      : docEl.classList.remove("keyboard-visible");
  }
}
