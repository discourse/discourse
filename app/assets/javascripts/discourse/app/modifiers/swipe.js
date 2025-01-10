import { registerDestructor } from "@ember/destroyable";
import { service } from "@ember/service";
import Modifier from "ember-modifier";
import {
  disableBodyScroll,
  enableBodyScroll,
} from "discourse/lib/body-scroll-lock";
import SwipeEvents from "discourse/lib/swipe-events";
import { bind } from "discourse-common/utils/decorators";
/**
 * A modifier for handling swipe gestures on an element.
 *
 * This Ember modifier is designed to attach swipe gesture listeners to the provided
 * element and execute callback functions based on the swipe direction and movement.
 * It utilizes touch events to determine the swipe direction and magnitude.
 * Callbacks for swipe start, move, and end can be passed as arguments and will be called
 * with the current state of the swipe, including its direction, orientation, and delta values.
 *
 * @example
 * <div {{swipe
 *        onDidStartSwipe=this.onDidStartSwipe
 *        onDidSwipe=this.onDidSwipe
 *        onDidEndSwipe=this.onDidEndSwipe
 *        onDidCancelSwipe=this.onDidCancelSwipe
 *      }}
 * >
 *   Swipe here
 * </div>
 *
 * @extends Modifier
 */

/**
 * SwipeModifier class.
 */
export default class SwipeModifier extends Modifier {
  @service site;

  /**
   * Creates an instance of SwipeModifier.
   * @param {Owner} owner - The owner.
   * @param {Object} args - The arguments.
   */
  constructor(owner, args) {
    super(owner, args);
    registerDestructor(this, (instance) => instance.cleanup());
  }

  /**
   * Modifies the element for swipe functionality.
   * @param {HTMLElement} element - The element to modify.
   * @param {*} _ - Unused argument.
   * @param {Object} options - Options for modifying the swipe behavior.
   * @param {Function} options.onDidStartSwipe - Callback function when swipe starts.
   * @param {Function} options.onDidSwipe - Callback function when swipe occurs.
   * @param {Function} options.onDidEndSwipe - Callback function when swipe ends.
   * @param {Function} options.onDidCancelSwipe - Callback function when swipe is canceled.
   * @param {boolean} options.enabled - Flag to enable/disable swipe.
   * @param {boolean} options.lockBody - Automatically enable/disable body scroll lock.
   */
  modify(
    element,
    _,
    {
      onDidStartSwipe,
      onDidSwipe,
      onDidEndSwipe,
      onDidCancelSwipe,
      enabled,
      lockBody,
    }
  ) {
    if (enabled === false || !this.site.mobileView) {
      this.enabled = enabled;
      return;
    }

    this.lockBody = lockBody ?? true;
    this.element = element;
    this.onDidSwipeCallback = onDidSwipe;
    this.onDidStartSwipeCallback = onDidStartSwipe;
    this.onDidCancelSwipeCallback = onDidCancelSwipe;
    this.onDidEndSwipeCallback = onDidEndSwipe;

    this._swipeEvents = new SwipeEvents(this.element);
    this._swipeEvents.addTouchListeners();
    this.element.addEventListener("swipestart", this.onDidStartSwipe);
    this.element.addEventListener("swipeend", this.onDidEndSwipe);
    this.element.addEventListener("swipecancel", this.onDidCancelSwipe);
    this.element.addEventListener("swipe", this.onDidSwipe);
    this.element.addEventListener("scroll", this.onScroll);
  }

  /**
   * Handler for swipe start event.
   * @param {Event} event - The swipe start event.
   */
  @bind
  onDidStartSwipe(event) {
    if (this.lockBody) {
      disableBodyScroll(this.element);
    }

    this.onDidStartSwipeCallback?.(event.detail);
  }

  /**
   * Handler for swipe end event.
   * @param {Event} event - The swipe end event.
   */
  @bind
  onDidEndSwipe() {
    if (this.lockBody) {
      enableBodyScroll(this.element);
    }

    this.onDidEndSwipeCallback?.(event.detail);
  }

  /**
   * Handler for swipe event.
   * @param {Event} event - The swipe event.
   */
  @bind
  onDidSwipe(event) {
    this.onDidSwipeCallback?.(event.detail);
  }

  /**
   * Handler for swipe cancel event.
   * @param {Event} event - The swipe cancel event.
   */
  @bind
  onDidCancelSwipe(event) {
    if (this.lockBody) {
      enableBodyScroll(this.element);
    }

    this.onDidCancelSwipeCallback?.(event.detail);
  }

  /**
   * Handler for scroll event. Prevents scrolling while swiping.
   */
  @bind
  onScroll(event) {
    event.preventDefault();
  }

  /**
   * Cleans up the swipe modifier.
   */
  cleanup() {
    if (!this.enabled || !this.element || !this._swipeEvents) {
      return;
    }

    this.element.removeEventListener("swipestart", this.onDidStartSwipe);
    this.element.removeEventListener("swipeend", this.onDidEndSwipe);
    this.element.removeEventListener("swipecancel", this.onDidCancelSwipe);
    this.element.removeEventListener("swipe", this.onDidSwipe);
    this.element.removeEventListener("scroll", this.onScroll);
    this._swipeEvents.removeTouchListeners();

    if (this.lockBody) {
      enableBodyScroll(this.element);
    }
  }
}
