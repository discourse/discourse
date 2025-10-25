import { registerDestructor } from "@ember/destroyable";
import { service } from "@ember/service";
import Modifier from "ember-modifier";
import { bind } from "discourse/lib/decorators";

/**
 * Modifier that prevents body scroll when focusing an input on iOS.
 *
 * This is a workaround for an iOS bug where the body scrolls when focusing
 * an input element near the keyboard, causing unwanted viewport scrolling.
 *
 * On non-iOS platforms, this modifier does nothing.
 */
export default class PreventScrollOnFocus extends Modifier {
  @service capabilities;

  constructor(owner, args) {
    super(owner, args);
    registerDestructor(this, (instance) => instance.cleanup());
  }

  modify(element) {
    if (!this.capabilities.isIOS) {
      return;
    }

    this.element = element;
    this.element.addEventListener("focus", this.preventScrollOnFocus);
  }

  /**
   * Focus event handler that prevents iOS scroll behavior.
   *
   * Creates a temporary off-screen clone of the input element, focuses the
   * clone first, then focuses the actual element. This technique prevents
   * iOS from scrolling the viewport when the input receives focus.
   *
   * The clone is positioned far off-screen and scaled to zero to ensure
   * it's not visible or interactable. After focusing both elements in
   * sequence, the clone is removed.
   *
   * Skips the clone process if:
   * - The relatedTarget is already a clone (to prevent infinite loops)
   * - The input type is "password" (to prevent issues with password managers)
   *
   * @param {FocusEvent} event - The focus event
   */
  @bind
  preventScrollOnFocus(event) {
    if (event.relatedTarget?.matches("[data-ios-input-clone]")) {
      return;
    }

    if (event.target.type === "password") {
      return;
    }

    const target = event.target;
    target.style.transform = "translateY(-99999px)";
    target.focus({ preventScroll: true });
    window.requestAnimationFrame(() => {
      window.requestAnimationFrame(() => {
        target.style.transform = "";
      });
    });
  }

  cleanup() {
    this.element?.removeEventListener("focus", this.preventScrollOnFocus);
  }
}
