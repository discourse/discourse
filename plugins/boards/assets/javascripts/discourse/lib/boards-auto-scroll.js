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
      // Limit detection requires synchronous scrolling, without smooth behavior.
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
    // Preserve native touch scrolling and pinch zoom.
    touchAction: "manipulation",
    // Apply a horizontal threshold below; the engine measures travel in both axes.
    threshold: 0,

    onDragStart: (event) => {
      cancelMomentum();

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
        // This class suppresses descendant pointer events, so wait for an actual pan.
        panning = true;
        element.classList.add(
          "discourse-boards-board-container--drag-scrolling"
        );
      }

      latestClientX = event.clientX;
      velocitySamples.push({ time: event.timeStamp, x: event.clientX });
      pruneVelocitySamples(event.timeStamp);

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

  /** Non-primary presses bypass the gesture callbacks but must stop momentum. */
  const onAnyPointerDown = () => cancelMomentum();
  const onWheel = () => cancelMomentum();

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
