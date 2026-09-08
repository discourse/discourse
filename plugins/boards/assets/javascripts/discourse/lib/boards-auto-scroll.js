import { modifier } from "ember-modifier";
import { registerPointerDrag } from "discourse/ui-kit/modifiers/d-pointer-drag";

const DRAG_SCROLL_SKIP_SELECTOR =
  ".discourse-boards-card, button, a, input, textarea, select, [contenteditable=''], [contenteditable='true']";

const DRAG_SCROLL_MOMENTUM_FRICTION = 0.92;
const DRAG_SCROLL_MOMENTUM_MAX_PX_PER_FRAME = 4;
const DRAG_SCROLL_MOMENTUM_MIN_PX_PER_FRAME = 0.5;
const DRAG_SCROLL_VELOCITY_WINDOW_MS = 80;
const DRAG_SCROLL_MS_PER_FRAME = 1000 / 60;
const DRAG_SCROLL_THRESHOLD = 4;

/**
 * Grab-to-pan the board: press on empty background, drag, and the board scrolls
 * with the pointer.
 *
 * `registerPointerDrag` owns the pointer lifecycle — capture, the primary-button
 * gate, pointer identity, the movement threshold and cancellation. What stays
 * here is what the gesture engine has no opinion about: which presses count,
 * and the velocity sampling and coast that make the release feel like a flick.
 */
export const dragToScroll = modifier((element) => {
  let startX = 0;
  let startScrollLeft = 0;
  let panning = false;
  let velocitySamples = [];
  let momentumFrame = null;
  let pendingMoveFrame = null;
  let latestClientX = 0;

  const cancelMomentum = () => {
    if (momentumFrame) {
      cancelAnimationFrame(momentumFrame);
      momentumFrame = null;
    }
  };

  const cancelPendingMove = () => {
    if (pendingMoveFrame) {
      cancelAnimationFrame(pendingMoveFrame);
      pendingMoveFrame = null;
    }
  };

  const pruneVelocitySamples = (now) => {
    const cutoff = now - DRAG_SCROLL_VELOCITY_WINDOW_MS;
    while (velocitySamples.length > 1 && velocitySamples[0].time < cutoff) {
      velocitySamples.shift();
    }
  };

  const startMomentum = (endTime) => {
    pruneVelocitySamples(endTime);
    if (velocitySamples.length < 2) {
      return;
    }

    const oldest = velocitySamples[0];
    const newest = velocitySamples[velocitySamples.length - 1];
    const dt = newest.time - oldest.time;
    if (dt <= 0) {
      return;
    }

    const pointerVelocityPerMs = (newest.x - oldest.x) / dt;
    let velocity = -pointerVelocityPerMs * DRAG_SCROLL_MS_PER_FRAME;
    velocity = Math.max(
      Math.min(velocity, DRAG_SCROLL_MOMENTUM_MAX_PX_PER_FRAME),
      -DRAG_SCROLL_MOMENTUM_MAX_PX_PER_FRAME
    );

    if (Math.abs(velocity) < DRAG_SCROLL_MOMENTUM_MIN_PX_PER_FRAME) {
      return;
    }

    const step = () => {
      const previous = element.scrollLeft;
      element.scrollLeft = previous + velocity;
      // The read-back is the limit test; it holds because this container does
      // not use `scroll-behavior: smooth`, under which the write would not be
      // observable synchronously.
      if (element.scrollLeft === previous) {
        momentumFrame = null;
        return;
      }

      velocity *= DRAG_SCROLL_MOMENTUM_FRICTION;
      if (Math.abs(velocity) < DRAG_SCROLL_MOMENTUM_MIN_PX_PER_FRAME) {
        momentumFrame = null;
        return;
      }
      momentumFrame = requestAnimationFrame(step);
    };

    momentumFrame = requestAnimationFrame(step);
  };

  const stopPanning = () => {
    panning = false;
    element.classList.remove(
      "discourse-boards-board-container--drag-scrolling"
    );
  };

  const releaseGesture = registerPointerDrag(element, () => ({
    // A large scroll surface, so native panning and pinch-zoom stay with the
    // browser; the default would suppress both.
    touchAction: "manipulation",
    // Left at 0 so the latch below can measure HORIZONTAL travel. The engine's
    // own threshold is a straight-line distance, which a vertical drag would
    // cross without ever meaning to pan sideways.
    threshold: 0,

    onDragStart: (event) => {
      cancelMomentum();

      // Touch scrolling is the browser's, and a press on anything interactive
      // belongs to that element. Refusing here releases the capture the engine
      // has already taken, so the click underneath still lands.
      if (
        event.pointerType === "touch" ||
        event.target.closest(DRAG_SCROLL_SKIP_SELECTOR) ||
        element.scrollWidth <= element.clientWidth
      ) {
        return false;
      }

      startX = event.clientX;
      startScrollLeft = element.scrollLeft;
      velocitySamples = [{ time: event.timeStamp, x: event.clientX }];
    },

    onDrag: (event) => {
      if (!panning) {
        if (Math.abs(event.clientX - startX) < DRAG_SCROLL_THRESHOLD) {
          return;
        }
        // Applied here rather than through `draggingClass`. The engine puts
        // that on when its own threshold engages, which at 0 means the press,
        // and this class suppresses pointer events on descendants, so a plain
        // click must never see it.
        panning = true;
        element.classList.add(
          "discourse-boards-board-container--drag-scrolling"
        );
      }

      latestClientX = event.clientX;
      velocitySamples.push({ time: event.timeStamp, x: event.clientX });
      pruneVelocitySamples(event.timeStamp);

      // Coalesced into a frame rather than written per event, as before the
      // gesture engine took over the lifecycle.
      if (pendingMoveFrame === null) {
        pendingMoveFrame = requestAnimationFrame(() => {
          pendingMoveFrame = null;
          element.scrollLeft = startScrollLeft - (latestClientX - startX);
        });
      }
    },

    onDragEnd: (event, info) => {
      const wasPanning = panning;
      cancelPendingMove();
      stopPanning();

      if (wasPanning && info.moved) {
        startMomentum(event.timeStamp);
      }
    },

    onDragCancel: () => {
      cancelPendingMove();
      stopPanning();
    },
  }));

  // Beside the gesture, not through it: a coast has to die on any press, and
  // the engine returns before its callbacks for a non-primary button.
  const onAnyPointerDown = () => cancelMomentum();
  const onWheel = () => cancelMomentum();

  // The engine does not suppress the click that follows a release, so a pan
  // would otherwise also activate whatever sat under the pointer.
  const onClickCapture = (event) => {
    if (panning) {
      event.stopPropagation();
      event.preventDefault();
    }
  };

  element.addEventListener("pointerdown", onAnyPointerDown);
  element.addEventListener("wheel", onWheel, { passive: true });
  element.addEventListener("click", onClickCapture, true);

  return () => {
    cancelMomentum();
    cancelPendingMove();
    releaseGesture();
    element.removeEventListener("pointerdown", onAnyPointerDown);
    element.removeEventListener("wheel", onWheel);
    element.removeEventListener("click", onClickCapture, true);
  };
});
