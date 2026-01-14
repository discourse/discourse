import { bind } from "discourse/lib/decorators";
import { headerOffset } from "discourse/lib/offset-calculator";

// Dear traveler, you are entering a zone where we are at war with the browser.
// The browser is insisting on positioning scrollTop per the location it was in
// the past, we are insisting on it being where we want it to be.
// The hack is just to keep trying over and over to position the scrollbar (up to 1 second).
//
// The root cause is that a "refresh" on a topic page will almost never be at the
// same position it was in the past, the URL points to the post at the top of the
// page, so a refresh will try to bring that post into view causing drift.
//
// Additionally if you loaded multiple batches of posts, on refresh they will not
// be loaded.
//
// This hack leads to a slight jerky experience, however other workarounds are more
// complex, the 2 options we have are
//
// 1. onbeforeunload ensure we are scrolled to the right spot
// 2. give up on the scrollbar and implement it ourselves (something that will happen)

const LOCK_DURATION_MS = 1000;
const LOCK_TIMEOUT_MS = 5000;
const SCROLL_EVENTS = ["scroll", "touchmove", "mousedown", "wheel", "keyup"];
const SCROLL_TYPES = ["mousedown", "mousewheel", "touchmove", "wheel"];

function within(threshold, x, y) {
  return Math.abs(x - y) < threshold;
}

export default class LockOn {
  constructor(selector, options) {
    this.selector = selector;
    this.options = options || {};
  }

  elementTop() {
    const element = document.querySelector(this.selector);
    if (!element) {
      return;
    }

    const { top } = element.getBoundingClientRect();
    let offset = top + window.scrollY;
    if (this.options.originalTopOffset) {
      // if element's original top offset is in the bottom half of the viewport
      // jump to it, otherwise respect the offset
      if (window.innerHeight / 2.25 > this.options.originalTopOffset) {
        return offset - this.options.originalTopOffset;
      }
    }

    return offset - headerOffset();
  }

  clearLock() {
    this._removeListener();
    window.cancelAnimationFrame(this._requestId);

    if (this.options.finished) {
      this.options.finished();
    }
  }

  lock() {
    this.startedAt = Date.now();
    this.previousTop = this.elementTop();

    if (this.previousTop) {
      window.scrollTo(window.pageXOffset, this.previousTop);
    }

    this._requestId = window.requestAnimationFrame(this._performLocking);

    this._removeListener();
    this._addListener();
  }

  @bind
  _scrollListener(event) {
    if (event.which > 0 || SCROLL_TYPES.includes(event.type)) {
      this.clearLock();
    }
  }

  _addListener() {
    SCROLL_EVENTS.forEach((event) => {
      document.body.addEventListener(event, this._scrollListener, {
        passive: true,
      });
    });
  }

  _removeListener() {
    SCROLL_EVENTS.forEach((event) => {
      document.body.removeEventListener(event, this._scrollListener);
    });
  }

  @bind
  _performLocking() {
    const elementTop = this.elementTop();

    // If we can't find the element yet, wait a little bit more
    if (!this.previousTop && !elementTop) {
      // …but not too long
      if (Date.now() - this.startedAt > LOCK_TIMEOUT_MS) {
        this.clearLock();
      }

      this._requestId = window.requestAnimationFrame(this._performLocking);
      return;
    }

    const top = Math.max(0, elementTop);

    if (isNaN(top)) {
      return this.clearLock();
    }

    if (!within(4, top, this.previousTop) || !within(4, window.scrollY, top)) {
      window.scrollTo(window.pageXOffset, top);
      this.previousTop = top;
    }

    // Stop early when maintaining the original offset
    if (this.options.originalTopOffset) {
      return this.clearLock();
    }

    // Stop after a little while
    if (Date.now() - this.startedAt > LOCK_DURATION_MS) {
      return this.clearLock();
    }

    this._requestId = window.requestAnimationFrame(this._performLocking);
  }
}
