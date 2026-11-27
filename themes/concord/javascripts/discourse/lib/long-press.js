const DELAY = 500;
// How far a finger may drift before the press counts as a scroll instead.
const SLOP = 10;

/**
 * Calls `onLongPress(element)` when a touch rests on an element matching
 * `selector`, the way into a channel's menu on phones. The tap that
 * ends the press doesn't follow the element's link, and the browser's own
 * long-press menu stays away.
 *
 * @returns {() => void} Removes the listeners.
 */
export default function installLongPress(selector, onLongPress) {
  let timer = null;
  let start = null;
  let fired = false;

  const cancel = () => {
    clearTimeout(timer);
    timer = null;
  };

  const listeners = {
    pointerdown(event) {
      const target = event.target.closest(selector);
      if (event.pointerType !== "touch" || !target) {
        return;
      }

      fired = false;
      start = { x: event.clientX, y: event.clientY };
      timer = setTimeout(() => {
        timer = null;
        fired = true;
        onLongPress(target);
      }, DELAY);
    },

    pointermove(event) {
      if (
        timer &&
        Math.hypot(event.clientX - start.x, event.clientY - start.y) > SLOP
      ) {
        cancel();
      }
    },

    pointerup: cancel,
    pointercancel: cancel,

    click(event) {
      if (fired && event.target.closest(selector)) {
        event.preventDefault();
        event.stopPropagation();
        fired = false;
      }
    },

    contextmenu(event) {
      if (event.target.closest(selector) && (timer || fired)) {
        event.preventDefault();
      }
    },
  };

  for (const [name, listener] of Object.entries(listeners)) {
    document.addEventListener(name, listener, { capture: true });
  }

  return () => {
    cancel();
    for (const [name, listener] of Object.entries(listeners)) {
      document.removeEventListener(name, listener, { capture: true });
    }
  };
}
