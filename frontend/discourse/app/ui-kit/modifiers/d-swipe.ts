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

  /** The event timestamp for this state, in milliseconds. */
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

  /** The element the gesture was reading, so a consumer can undo what it painted. */
  element: HTMLElement;
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

      /** Called when the first touch lands, before it becomes a swipe. */
      onDidPress?: (event: TouchEvent) => void;

      /** Called when that touch is released without starting a swipe. */
      onDidRelease?: (event: TouchEvent) => void;

      /** Whether swipe handling is enabled. Defaults to `true`; always off on desktop. */
      enabled?: boolean;

      /** Whether to lock body scrolling for the duration of the gesture. Defaults to `true`. */
      lockBody?: boolean;
    };
    Positional: [];
  };
}

/**
 * Recognizes directional touch gestures and reports their lifecycle. Touch only:
 * it does nothing on desktop.
 *
 * Calling `preventDefault()` on the event passed to `onDidStartSwipe` refuses
 * that gesture, so nothing further is reported for it and the browser keeps the
 * touch. The next gesture starts fresh. A consumer that only wants one axis, or
 * that has to leave a scroll to the content, vetoes here.
 *
 * Guide to choosing between the gesture primitives:
 * `docs/developer-guides/docs/03-code-internals/29-drag-and-gesture-primitives.md`
 *
 * @see The `dPointerDrag` modifier, for any pointer rather than touch alone, and
 *   for a value tracked continuously rather than a directional flick.
 */
export default class DSwipeModifier extends Modifier<DSwipeSignature> {
  @service declare site: Site;

  #lockBody = false;
  #bodyLocked = false;
  #element?: HTMLElement;
  #swipeEvents?: SwipeEvents;
  #onDidStartSwipeCallback?: (state: SwipeState, event: Event) => void;
  #onDidSwipeCallback?: (state: SwipeState) => void;
  #onDidEndSwipeCallback?: (state: SwipeState) => void;
  #onDidCancelSwipeCallback?: (detail: SwipeCancelDetail) => void;
  #onDidPressCallback?: (event: TouchEvent) => void;
  #onDidReleaseCallback?: (event: TouchEvent) => void;
  #pressActive = false;
  #swiping = false;

  constructor(owner: Owner, args: ArgsFor<DSwipeSignature>) {
    super(owner, args);
    registerDestructor(this, () => this.#cleanup());
  }

  modify(
    element: HTMLElement,
    _positional: [],
    {
      onDidStartSwipe,
      onDidSwipe,
      onDidEndSwipe,
      onDidCancelSwipe,
      onDidPress,
      onDidRelease,
      enabled,
      lockBody,
    }: DSwipeSignature["Args"]["Named"]
  ) {
    this.#cleanup();

    if (enabled === false || this.site.desktopView) {
      return;
    }

    this.#lockBody = lockBody ?? true;
    this.#element = element;
    this.#onDidSwipeCallback = onDidSwipe;
    this.#onDidStartSwipeCallback = onDidStartSwipe;
    this.#onDidCancelSwipeCallback = onDidCancelSwipe;
    this.#onDidEndSwipeCallback = onDidEndSwipe;
    this.#onDidPressCallback = onDidPress;
    this.#onDidReleaseCallback = onDidRelease;

    this.#swipeEvents = new SwipeEvents(this.#element);
    this.#swipeEvents.addTouchListeners();
    this.#element.addEventListener("swipestart", this.onDidStartSwipe);
    this.#element.addEventListener("swipeend", this.onDidEndSwipe);
    this.#element.addEventListener("swipecancel", this.onDidCancelSwipe);
    this.#element.addEventListener("swipe", this.onDidSwipe);
    this.#element.addEventListener("scroll", this.onScroll);
    this.#element.addEventListener("touchstart", this.onPress);
    this.#element.addEventListener("touchend", this.onRelease);
    this.#element.addEventListener("touchcancel", this.onPressCancel);
  }

  @bind
  onDidStartSwipe(event: Event) {
    const { detail } = event as CustomEvent<SwipeState>;
    this.#onDidStartSwipeCallback?.(detail, event);

    if (event.defaultPrevented) {
      return;
    }

    this.#swiping = true;

    if (this.#lockBody) {
      // `body-scroll-lock` is a vendored bundle whose optional `options` argument is
      // typed as required; passing `undefined` keeps the original single-argument call.
      lock(this.#element, undefined);
      this.#bodyLocked = true;
    }
  }

  @bind
  onDidEndSwipe(event: Event) {
    const { detail } = event as CustomEvent<SwipeState>;
    this.#unlockBody();
    this.#onDidEndSwipeCallback?.(detail);
  }

  @bind
  onDidSwipe(event: Event) {
    const { detail } = event as CustomEvent<SwipeState>;
    this.#onDidSwipeCallback?.(detail);
  }

  @bind
  onDidCancelSwipe(event: Event) {
    const { detail } = event as CustomEvent<SwipeCancelDetail>;
    this.#unlockBody();
    this.#onDidCancelSwipeCallback?.(detail);
  }

  @bind
  onPress(event: TouchEvent) {
    if (event.touches.length !== 1) {
      return;
    }
    this.#pressActive = true;
    this.#onDidPressCallback?.(event);
  }

  @bind
  onRelease(event: TouchEvent) {
    if (this.#pressActive && !this.#swiping) {
      this.#onDidReleaseCallback?.(event);
    }
    this.#pressActive = false;
    this.#swiping = false;
  }

  @bind
  onPressCancel() {
    this.#pressActive = false;
    this.#swiping = false;
  }

  @bind
  onScroll(event: Event) {
    event.preventDefault();
  }

  #cleanup() {
    if (!this.#element || !this.#swipeEvents) {
      return;
    }

    this.#element.removeEventListener("swipestart", this.onDidStartSwipe);
    this.#element.removeEventListener("swipeend", this.onDidEndSwipe);
    this.#element.removeEventListener("swipecancel", this.onDidCancelSwipe);
    this.#element.removeEventListener("swipe", this.onDidSwipe);
    this.#element.removeEventListener("scroll", this.onScroll);
    this.#element.removeEventListener("touchstart", this.onPress);
    this.#element.removeEventListener("touchend", this.onRelease);
    this.#element.removeEventListener("touchcancel", this.onPressCancel);
    this.#swipeEvents.removeTouchListeners();
    this.#unlockBody();
    this.#element = undefined;
    this.#swipeEvents = undefined;
    this.#pressActive = false;
    this.#swiping = false;
  }

  #unlockBody() {
    if (this.#bodyLocked) {
      unlock(this.#element, undefined);
      this.#bodyLocked = false;
    }
  }
}
