import Component from "@glimmer/component";
import { cancel, scheduleOnce } from "@ember/runloop";
import { service } from "@ember/service";
import discourseDebounce from "discourse/lib/debounce";
import { bind } from "discourse/lib/decorators";
import { summonsSoftKeyboard } from "discourse/lib/dom-utils";
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

export default class DVirtualHeight extends Component {
  @service site;
  @service capabilities;
  @service appEvents;

  #removeListeners = [];

  constructor() {
    super(...arguments);

    if (!window.visualViewport) {
      return;
    }

    if (!this.capabilities.isIpadOS && this.site.desktopView) {
      return;
    }

    scheduleOnce("afterRender", this, this.debouncedOnViewportResize);

    this.appEvents.on("keyboard:will-hide", this, this.onKeyboardWillHide);

    this.#listen(
      window.visualViewport,
      "resize",
      this.debouncedOnViewportResize
    );
    this.#listen(document, "focusout", this.onFocusOut);
    this.#listen(document, "focusin", this.onFocusIn);

    const touchOptions = { passive: true, capture: true };
    this.#listen(document, "touchstart", this.onTouchStart, touchOptions);
    this.#listen(document, "touchend", this.onTouchEnd, touchOptions);
    this.#listen(document, "touchcancel", this.onTouchCancel, touchOptions);

    // browser-chrome taps (e.g. the address bar) dismiss with no page event
    this.#listen(window, "blur", this.onWindowBlur);
  }

  willDestroy() {
    super.willDestroy(...arguments);

    cancel(this.debouncedHandler);
    cancel(this.focusSettleHandler);
    cancel(this.showConfirmHandler);
    this.clearGhostTapSuppression?.();

    this.appEvents.off("keyboard:will-hide", this, this.onKeyboardWillHide);
    this.#removeListeners.forEach((remove) => remove());
  }

  #listen(target, type, handler, options) {
    target.addEventListener(type, handler, options);
    this.#removeListeners.push(() =>
      target.removeEventListener(type, handler, options)
    );
  }

  #applyHeight(height) {
    this.previousHeight = height;
    document.documentElement.style.setProperty(
      "--composer-vh",
      `${height / 100}px`
    );
  }

  #announceKeyboard(visible) {
    this.appEvents.trigger("keyboard-visibility-change", visible);
    document.documentElement.classList.toggle("keyboard-visible", visible);
  }

  @bind
  onTouchStart(event) {
    // a click that follows a new touch is that tap's own, not a ghost
    this.clearGhostTapSuppression?.();

    const touch = event.touches?.[0];
    const target = event.target instanceof Element ? event.target : null;
    this.lastTouch = {
      at: Date.now(),
      x: touch?.clientX ?? 0,
      y: touch?.clientY ?? 0,
      target,
      moved: false,
      inert: !!target && !target.closest(FOCUS_CAPABLE_SELECTOR),
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

    const hadKeyboard =
      document.documentElement.classList.contains("keyboard-visible");
    this.onKeyboardWillHide();

    // an in-page chrome tap (e.g. the address bar) keeps DOM focus, so no
    // focus event would correct the stranded editor; release it so a later
    // tap refocuses. backgrounding stays visible=hidden and is left for the
    // OS to restore
    if (
      hadKeyboard &&
      document.visibilityState === "visible" &&
      !this.#recentTouch() &&
      summonsSoftKeyboard(document.activeElement)
    ) {
      document.activeElement.blur();
    }
  }

  @bind
  onFocusOut() {
    if (!document.documentElement.classList.contains("keyboard-visible")) {
      return;
    }

    cancel(this.focusSettleHandler);

    if (this.#recentTouch() && this.lastTouch.inert) {
      this.onKeyboardWillHide();

      // the tap's synthesized click would land on controls the reflow just
      // moved; drags synthesize none
      if (!this.lastTouch.moved) {
        this.#suppressGhostTap(this.lastTouch.target);
      }
      return;
    }

    this.focusSettleHandler = discourseDebounce(
      this,
      this.onFocusSettled,
      FOCUS_SETTLE_MS
    );
  }

  #recentTouch() {
    return !!this.lastTouch && Date.now() - this.lastTouch.at < RECENT_TOUCH_MS;
  }

  #suppressGhostTap(touchedTarget) {
    this.clearGhostTapSuppression?.();

    const swallow = (event) => {
      // let the tap through if it still lands on what was touched; only the
      // reflow displacing a control under the finger is a ghost
      if (event.target !== touchedTarget) {
        event.preventDefault();
        event.stopPropagation();
      }
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
    if (!summonsSoftKeyboard(document.activeElement)) {
      this.onKeyboardWillHide();
    }
  }

  // reflow immediately instead of waiting for the visualViewport resize,
  // which only fires after the OS hide animation
  onKeyboardWillHide() {
    if (
      !document.documentElement.classList.contains("keyboard-visible") ||
      isZoomed()
    ) {
      return;
    }

    cancel(this.debouncedHandler);
    cancel(this.showConfirmHandler);
    this.showPredicted = false;

    this.inferredHideAt = Date.now();
    this.lastKeyboardHeight = this.previousHeight;
    this.#applyHeight(Math.round(window.innerHeight));
    this.#announceKeyboard(false);
  }

  @bind
  onFocusIn(event) {
    if (
      !summonsSoftKeyboard(event.target) ||
      document.documentElement.classList.contains("keyboard-visible") ||
      isZoomed()
    ) {
      return;
    }

    cancel(this.focusSettleHandler);

    // apply the last known keyboard height ahead of its show animation, when
    // the tap landed on the field being focused — a tap that programmatically
    // focuses something else (a chooser's filter input) may raise no
    // keyboard — or right after an inferred hide: a refocus mid-hide (e.g. a
    // modal autofocusing its input) cancels the OS animation and the
    // unchanged viewport never reports back. a wrong guess is corrected by
    // the revert timer or the next real viewport report
    if (
      this.lastKeyboardHeight &&
      (this.#tappedInto(event.target) || this.#midInferredHide())
    ) {
      this.#showKeyboardState(this.lastKeyboardHeight);
      this.#armShowConfirm();
    }
  }

  #tappedInto(focused) {
    const touch = this.lastTouch;
    return (
      this.#recentTouch() &&
      !!touch.target &&
      (focused === touch.target || focused.contains(touch.target))
    );
  }

  #midInferredHide() {
    return (
      !!this.inferredHideAt &&
      Date.now() - this.inferredHideAt < VIEWPORT_CONFIRM_MS
    );
  }

  #showKeyboardState(height) {
    // a hide-report resize may still sit in the debounce; it would strip
    // the state we are applying right here
    cancel(this.debouncedHandler);

    this.#applyHeight(height);
    this.#announceKeyboard(true);

    // this optimistic height animates the composer up in step with the
    // keyboard; the real viewport report that follows only corrects it, and
    // that correction must not re-animate (see onViewportResize)
    this.showPredicted = true;
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
  }

  setVH() {
    if (isZoomed()) {
      return;
    }

    const height = Math.round(window.visualViewport.height);

    if (this.previousHeight && Math.abs(this.previousHeight - height) <= 1) {
      return false;
    }

    this.#applyHeight(height);
  }

  @bind
  debouncedOnViewportResize() {
    this.debouncedHandler = discourseDebounce(this, this.onViewportResize, 50);
  }

  @bind
  onViewportResize() {
    // the real viewport report supersedes any optimistic guess
    cancel(this.showConfirmHandler);
    this.inferredHideAt = null;

    // when this report is correcting a predicted show, the composer has
    // already glided to the predicted height; snap the (small) correction so
    // it doesn't run a second, visible height animation
    const composer =
      this.showPredicted && document.getElementById("reply-control");
    this.showPredicted = false;

    if (composer) {
      composer.style.transition = "none";
    }

    const changed = this.setVH() !== false;

    if (composer) {
      composer.offsetHeight; // flush the snapped height before restoring
      composer.style.transition = "";
    }

    if (!changed) {
      return;
    }

    const keyboardVisible =
      window.innerHeight - window.visualViewport.height >
      KEYBOARD_DETECT_THRESHOLD;

    if (keyboardVisible) {
      this.lastKeyboardHeight = this.previousHeight;
    }

    this.#announceKeyboard(keyboardVisible);
  }
}
