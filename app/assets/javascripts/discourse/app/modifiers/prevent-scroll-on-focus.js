import { registerDestructor } from "@ember/destroyable";
import { later } from "@ember/runloop";
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

    const clone = event.target.cloneNode(false);
    clone.removeAttribute("id");
    clone.dataset.iosInputClone = true;
    clone.style.setProperty("position", "fixed");
    clone.style.setProperty("left", "0");
    clone.style.setProperty("top", "0");
    clone.style.setProperty("transform", "translateY(-3000px) scale(0)");
    document.documentElement.appendChild(clone);
    clone.focus({ preventScroll: true });

    later(() => {
      event.target.focus({ preventScroll: true });
      clone.remove();
    }, 32);
  }

  cleanup() {
    this.element?.removeEventListener("focus", this.preventScrollOnFocus);
  }
}
