import { minimumOffset } from "discourse/lib/offset-calculator";

// Dear traveller, you are entering a zone where we are at war with the browser.
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
const SCROLL_EVENTS =
  "scroll.lock-on touchmove.lock-on mousedown.lock-on wheel.lock-on DOMMouseScroll.lock-on mousewheel.lock-on keyup.lock-on";
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
    const $selected = $(this.selector);
    if ($selected && $selected.offset && $selected.offset()) {
      return $selected.offset().top - minimumOffset();
    }
  }

  clearLock(interval) {
    $("body, html").off(SCROLL_EVENTS);
    clearInterval(interval);
    if (this.options.finished) {
      this.options.finished();
    }
  }

  lock() {
    let previousTop = this.elementTop();
    const startedAt = new Date().getTime();

    $(window).scrollTop(previousTop);

    const interval = setInterval(() => {
      const top = Math.max(0, this.elementTop());
      const scrollTop = $(window).scrollTop();

      if (typeof top === "undefined" || isNaN(top)) {
        return this.clearLock(interval);
      }

      if (!within(4, top, previousTop) || !within(4, scrollTop, top)) {
        $(window).scrollTop(top);
        previousTop = top;
      }

      // Commit suicide after a little while
      if (new Date().getTime() - startedAt > LOCK_DURATION_MS) {
        return this.clearLock(interval);
      }
    }, 50);

    $("body, html")
      .off(SCROLL_EVENTS)
      .on(SCROLL_EVENTS, e => {
        if (e.which > 0 || SCROLL_TYPES.includes(e.type)) {
          this.clearLock(interval);
        }
      });
  }
}
