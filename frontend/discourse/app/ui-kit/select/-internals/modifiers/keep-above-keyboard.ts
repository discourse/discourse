import { registerDestructor } from "@ember/destroyable";
import type Owner from "@ember/owner";
import Modifier, { type ArgsFor } from "ember-modifier";

// How far the query input may sit under the keyboard before it is worth scrolling. A pixel or
// two is rounding, not occlusion.
const KEYBOARD_OCCLUSION_TOLERANCE = 4;

// Breathing room above the keyboard once corrected, so the input does not end up flush against
// it. An allowance, not a measurement.
const KEYBOARD_OCCLUSION_MARGIN = 24;

interface KeepAboveKeyboardSignature {
  Element: HTMLElement;
  Args: {
    Positional: [shouldCorrect: () => boolean];
  };
}

/**
 * Keeps the focused query input above the iOS software keyboard.
 *
 * WebKit decides where to scroll when the keyboard opens, and it does not account for the
 * overlay this component renders: it intermittently leaves the input underneath the keyboard,
 * with the panel still correctly positioned against it. Nothing in CSS prevents that — Safari
 * has already scrolled by then — so the only remedy is to measure afterwards and correct,
 * which is what `setupComposerPosition` does for the composer.
 *
 * The measurement is the whole of it: `visualViewport.height` is the bottom of the visible
 * area in client coordinates, which is what `getBoundingClientRect()` returns, so the two are
 * directly comparable and their difference is how far the input is buried.
 *
 * `offsetTop` is deliberately NOT added. Treating the visible band as
 * `[offsetTop, offsetTop + height]` is the correct reading for a pinch-zoomed viewport, but
 * with the keyboard raised iPadOS reports an `offsetTop` matching nothing clipped off the top.
 * Adding it pushes the computed bottom below the keyboard's accessory bar, so an input sitting
 * under that bar measures as clear and no correction runs. The two readings agree whenever
 * `offsetTop` is zero, which is why the input was hidden only sometimes: same page, same
 * input, and only the reported offset differing between a working case and a broken one.
 *
 * Runs only while the widget holds focus, only where the bug exists, and only when the input
 * is genuinely occluded, so a correctly-behaving browser is never scrolled.
 */
export default class KeepAboveKeyboard extends Modifier<KeepAboveKeyboardSignature> {
  #element: HTMLElement | null = null;
  #isListening = false;
  #shouldCorrect: (() => boolean) | null = null;

  #keepAboveKeyboard = (): void => {
    const element = this.#element;
    if (!this.#shouldCorrect?.() || !element?.isConnected) {
      return;
    }

    const viewport = window.visualViewport;
    if (!viewport) {
      return;
    }

    const hidden = element.getBoundingClientRect().bottom - viewport.height;
    if (hidden <= KEYBOARD_OCCLUSION_TOLERANCE) {
      return;
    }

    window.scrollTo({
      top: window.scrollY + hidden + KEYBOARD_OCCLUSION_MARGIN,
      behavior: "instant",
    });
  };

  constructor(owner: Owner, args: ArgsFor<KeepAboveKeyboardSignature>) {
    super(owner, args);
    registerDestructor(this, () => this.#cleanup());
  }

  modify(
    element: HTMLElement,
    [shouldCorrect]: KeepAboveKeyboardSignature["Args"]["Positional"]
  ): void {
    this.#element = element;
    this.#shouldCorrect = shouldCorrect;

    if (!this.#isListening) {
      // Both events matter: `resize` is the keyboard opening or closing, `scroll` is WebKit
      // moving the page underneath it afterwards.
      window.visualViewport?.addEventListener(
        "resize",
        this.#keepAboveKeyboard
      );
      window.visualViewport?.addEventListener(
        "scroll",
        this.#keepAboveKeyboard
      );
      this.#isListening = true;
    }
  }

  #cleanup(): void {
    window.visualViewport?.removeEventListener(
      "resize",
      this.#keepAboveKeyboard
    );
    window.visualViewport?.removeEventListener(
      "scroll",
      this.#keepAboveKeyboard
    );
    this.#element = null;
    this.#shouldCorrect = null;
    this.#isListening = false;
  }
}
