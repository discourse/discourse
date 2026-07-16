import { registerDestructor } from "@ember/destroyable";
import type Owner from "@ember/owner";
import { service } from "@ember/service";
import Modifier, { type ArgsFor } from "ember-modifier";
import { lock, unlock } from "discourse/lib/body-scroll-lock";
import { bind } from "discourse/lib/decorators";
import SwipeEvents from "discourse/lib/swipe-events";
import type Site from "discourse/models/site";

/**
 * The gesture state reported by the `swipe-events` custom events and handed to the
 * start, move, and end callbacks.
 */
export interface SwipeState {
  /** The pointer coordinates where the gesture started. */
  startLocation: { x: number; y: number };

  /** The current pointer coordinates. */
  center: { x: number; y: number };

  /** The horizontal velocity, in pixels per millisecond. */
  velocityX: number;

  /** The vertical velocity, in pixels per millisecond. */
  velocityY: number;

  /** The horizontal displacement from `startLocation`, in pixels. */
  deltaX: number;

  /** The vertical displacement from `startLocation`, in pixels. */
  deltaY: number;

  /** Whether this is the first state of the gesture. */
  start: boolean;

  /** When this state was produced, as an epoch timestamp in milliseconds. */
  timestamp: number;

  /** The dominant direction of the gesture, fixed once first determined. */
  direction: "up" | "down" | "left" | "right";

  /** The element the gesture is tracked on. */
  element: HTMLElement;

  /** Returns whether the gesture direction is `"up"`. */
  goingUp: () => boolean;

  /** Returns whether the gesture direction is `"down"`. */
  goingDown: () => boolean;

  /** The underlying DOM event that produced this state. */
  originalEvent?: Event;
}

/** The detail reported when a gesture is cancelled. */
export interface SwipeCancelDetail {
  /** The underlying DOM event that triggered the cancellation. */
  originalEvent: Event;
}

interface DSwipeSignature {
  /** The element the swipe listeners are attached to. */
  Element: HTMLElement;
  Args: {
    Named: {
      /**
       * Called when a gesture starts. Calling `preventDefault()` on the event
       * cancels the gesture: the body is not locked and no further swipe events
       * fire for it.
       */
      onDidStartSwipe?: (state: SwipeState, event: Event) => void;

      /** Called on each pointer move while the gesture is in progress. */
      onDidSwipe?: (state: SwipeState) => void;

      /** Called when the gesture ends. */
      onDidEndSwipe?: (state: SwipeState) => void;

      /** Called when the gesture is cancelled, e.g. by a second touch. */
      onDidCancelSwipe?: (detail: SwipeCancelDetail) => void;

      /** Whether swipe handling is enabled. Defaults to `true`; always off on desktop. */
      enabled?: boolean;

      /** Whether to lock body scrolling for the duration of the gesture. Defaults to `true`. */
      lockBody?: boolean;
    };
    Positional: [];
  };
}

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
 */
export default class DSwipeModifier extends Modifier<DSwipeSignature> {
  @service declare site: Site;

  #enabled = false;
  #lockBody = false;
  #bodyLocked = false;
  #element?: HTMLElement;
  #swipeEvents?: SwipeEvents;
  #onDidStartSwipeCallback?: (state: SwipeState, event: Event) => void;
  #onDidSwipeCallback?: (state: SwipeState) => void;
  #onDidEndSwipeCallback?: (state: SwipeState) => void;
  #onDidCancelSwipeCallback?: (detail: SwipeCancelDetail) => void;

  constructor(owner: Owner, args: ArgsFor<DSwipeSignature>) {
    super(owner, args);
    registerDestructor(this, () => this.#cleanup());
  }

  /**
   * Modifies the element for swipe functionality.
   *
   * @param element - The element to modify.
   * @param _positional - Unused positional arguments.
   * @param named - Options for modifying the swipe behavior.
   */
  modify(
    element: HTMLElement,
    _positional: [],
    {
      onDidStartSwipe,
      onDidSwipe,
      onDidEndSwipe,
      onDidCancelSwipe,
      enabled,
      lockBody,
    }: DSwipeSignature["Args"]["Named"]
  ) {
    if (enabled === false || this.site.desktopView) {
      this.#enabled = false;
      return;
    }

    this.#enabled = true;
    this.#lockBody = lockBody ?? true;
    this.#element = element;
    this.#onDidSwipeCallback = onDidSwipe;
    this.#onDidStartSwipeCallback = onDidStartSwipe;
    this.#onDidCancelSwipeCallback = onDidCancelSwipe;
    this.#onDidEndSwipeCallback = onDidEndSwipe;

    this.#swipeEvents = new SwipeEvents(this.#element);
    this.#swipeEvents.addTouchListeners();
    this.#element.addEventListener("swipestart", this.onDidStartSwipe);
    this.#element.addEventListener("swipeend", this.onDidEndSwipe);
    this.#element.addEventListener("swipecancel", this.onDidCancelSwipe);
    this.#element.addEventListener("swipe", this.onDidSwipe);
    this.#element.addEventListener("scroll", this.onScroll);
  }

  /**
   * Handler for the swipe start event. The callback can cancel the gesture by
   * calling `preventDefault()` on the event, in which case the body is not
   * locked and no further swipe events are fired for this gesture.
   */
  @bind
  onDidStartSwipe(event: Event) {
    const { detail } = event as CustomEvent<SwipeState>;
    this.#onDidStartSwipeCallback?.(detail, event);

    if (event.defaultPrevented) {
      return;
    }

    if (this.#lockBody) {
      // `body-scroll-lock` is a vendored bundle whose optional `options` argument is
      // typed as required; passing `undefined` keeps the original single-argument call.
      lock(this.#element, undefined);
      this.#bodyLocked = true;
    }
  }

  /**
   * Handler for the swipe end event.
   */
  @bind
  onDidEndSwipe(event: Event) {
    const { detail } = event as CustomEvent<SwipeState>;
    this.#unlockBody();
    this.#onDidEndSwipeCallback?.(detail);
  }

  /**
   * Handler for the swipe event.
   */
  @bind
  onDidSwipe(event: Event) {
    const { detail } = event as CustomEvent<SwipeState>;
    this.#onDidSwipeCallback?.(detail);
  }

  /**
   * Handler for the swipe cancel event.
   */
  @bind
  onDidCancelSwipe(event: Event) {
    const { detail } = event as CustomEvent<SwipeCancelDetail>;
    this.#unlockBody();
    this.#onDidCancelSwipeCallback?.(detail);
  }

  /**
   * Handler for the scroll event. Prevents scrolling while swiping.
   */
  @bind
  onScroll(event: Event) {
    event.preventDefault();
  }

  #cleanup() {
    if (!this.#enabled || !this.#element || !this.#swipeEvents) {
      return;
    }

    this.#element.removeEventListener("swipestart", this.onDidStartSwipe);
    this.#element.removeEventListener("swipeend", this.onDidEndSwipe);
    this.#element.removeEventListener("swipecancel", this.onDidCancelSwipe);
    this.#element.removeEventListener("swipe", this.onDidSwipe);
    this.#element.removeEventListener("scroll", this.onScroll);
    this.#swipeEvents.removeTouchListeners();
    this.#unlockBody();
  }

  #unlockBody() {
    if (this.#bodyLocked) {
      unlock(this.#element, undefined);
      this.#bodyLocked = false;
    }
  }
}
