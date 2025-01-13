import { tracked } from "@glimmer/tracking";
import { throttle } from "@ember/runloop";
import Service, { service } from "@ember/service";
import { disableImplicitInjections } from "discourse/lib/implicit-injections";
import discourseDebounce from "discourse-common/lib/debounce";
import { bind } from "discourse-common/utils/decorators";

// Small buffer so that very tiny scrolls don't trigger mobile header switch
const MOBILE_SCROLL_TOLERANCE = 5;

const PAUSE_AFTER_TRANSITION_MS = 1000;

export const UNSCROLLED = Symbol("unscrolled"),
  SCROLLED_DOWN = Symbol("scroll-down"),
  SCROLLED_UP = Symbol("scroll-up");

@disableImplicitInjections
export default class ScrollDirection extends Service {
  @service router;
  @tracked lastScrollDirection = UNSCROLLED;

  #lastScroll = null;
  #bottomHit = 0;
  #paused = false;

  constructor() {
    super(...arguments);
    this.routeDidChange();
    window.addEventListener("scroll", this.onScroll, { passive: true });
    this.router.on("routeWillChange", this.routeWillChange);
    this.router.on("routeDidChange", this.routeDidChange);
  }

  willDestroy() {
    window.removeEventListener("scroll", this.onScroll);
    this.router.off("routeDidChange", this.routeDidChange);
  }

  @bind
  routeWillChange() {
    // Pause detection until the transition is over
    this.#paused = true;
  }

  @bind
  routeDidChange() {
    this.#paused = true;

    // User hasn't scrolled yet on this route
    this.lastScrollDirection = UNSCROLLED;

    // Allow a bit of extra time for any DOM shifts to settle
    discourseDebounce(this.unpause, PAUSE_AFTER_TRANSITION_MS);
  }

  @bind
  unpause() {
    this.#paused = false;
  }

  @bind
  onScroll() {
    if (this.#paused) {
      this.#lastScroll = window.scrollY;
      return;
    } else {
      throttle(this.handleScroll, 100, false);
    }
  }

  @bind
  handleScroll() {
    // Unfortunately no public API for this
    // eslint-disable-next-line ember/no-private-routing-service
    if (this.router._router._routerMicrolib.activeTransition) {
      // console.log("activetransition");
      return;
    }

    const offset = window.scrollY;
    this.calculateDirection(offset);
  }

  calculateDirection(offset) {
    // Difference between this scroll and the one before it.
    const delta = Math.floor(offset - this.#lastScroll);

    // This is a tiny scroll, so we ignore it.
    if (delta <= MOBILE_SCROLL_TOLERANCE && delta >= -MOBILE_SCROLL_TOLERANCE) {
      return;
    }

    // don't calculate when resetting offset (i.e. going to /latest or to next topic in suggested list)
    if (offset === 0) {
      return;
    }

    const prevDirection = this.lastScrollDirection;
    const currDirection = delta > 0 ? SCROLLED_DOWN : SCROLLED_UP;

    const distanceToBottom = Math.floor(
      document.body.clientHeight - offset - window.innerHeight
    );

    // Handle Safari top overscroll first
    if (offset < 0) {
      this.lastScrollDirection = UNSCROLLED;
    } else if (currDirection !== prevDirection && distanceToBottom > 0) {
      this.lastScrollDirection = currDirection;
    }

    // We store this to compare against it the next time the user scrolls
    this.#lastScroll = Math.floor(offset);

    if (distanceToBottom > 0) {
      this.#bottomHit = 0;
    } else {
      // If the user reaches the very bottom of the topic, we only want to reset
      // this scroll direction after a second scroll down. This is a nicer event
      // similar to what Safari and Chrome do.
      discourseDebounce(this, this.#setBottomHit, 1000);

      if (this.#bottomHit === 1) {
        this.lastScrollDirection = UNSCROLLED;
      }
    }

    this.lastScrollTimestamp = Date.now();
  }

  #setBottomHit() {
    this.#bottomHit = 1;
  }
}
