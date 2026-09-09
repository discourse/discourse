import { modifier } from "ember-modifier";

const AUTO_SCROLL_EDGE_SIZE = 72;
const AUTO_SCROLL_MAX_SPEED = 10;

export function autoScrollSpeedForPointer(pointerPosition, rect, axis = "y") {
  if (!rect) {
    return 0;
  }

  const startEdge = axis === "x" ? rect.left : rect.top;
  const endEdge = axis === "x" ? rect.right : rect.bottom;

  const startDistance = pointerPosition - startEdge;
  if (startDistance < AUTO_SCROLL_EDGE_SIZE) {
    return -Math.ceil(
      ((AUTO_SCROLL_EDGE_SIZE - Math.max(startDistance, 0)) /
        AUTO_SCROLL_EDGE_SIZE) *
        AUTO_SCROLL_MAX_SPEED
    );
  }

  const endDistance = endEdge - pointerPosition;
  if (endDistance < AUTO_SCROLL_EDGE_SIZE) {
    return Math.ceil(
      ((AUTO_SCROLL_EDGE_SIZE - Math.max(endDistance, 0)) /
        AUTO_SCROLL_EDGE_SIZE) *
        AUTO_SCROLL_MAX_SPEED
    );
  }

  return 0;
}

const DRAG_SCROLL_SKIP_SELECTOR =
  ".discourse-boards-card, button, a, input, textarea, select, [contenteditable=''], [contenteditable='true']";

const DRAG_SCROLL_MOMENTUM_FRICTION = 0.92;
const DRAG_SCROLL_MOMENTUM_MAX_PX_PER_FRAME = 4;
const DRAG_SCROLL_MOMENTUM_MIN_PX_PER_FRAME = 0.5;
const DRAG_SCROLL_VELOCITY_WINDOW_MS = 80;
const DRAG_SCROLL_MS_PER_FRAME = 1000 / 60;

export const dragToScroll = modifier((element) => {
  let activePointerId = null;
  let startX = 0;
  let startScrollLeft = 0;
  let dragStarted = false;
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

  const recordSample = (event) => {
    velocitySamples.push({ time: event.timeStamp, x: event.clientX });
    pruneVelocitySamples(event.timeStamp);
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

  const onPointerDown = (event) => {
    cancelMomentum();

    if (event.button !== 0 || event.pointerType === "touch") {
      return;
    }
    if (event.target.closest(DRAG_SCROLL_SKIP_SELECTOR)) {
      return;
    }
    if (element.scrollWidth <= element.clientWidth) {
      return;
    }

    activePointerId = event.pointerId;
    startX = event.clientX;
    startScrollLeft = element.scrollLeft;
    dragStarted = false;
    velocitySamples = [{ time: event.timeStamp, x: event.clientX }];
  };

  const onPointerMove = (event) => {
    if (event.pointerId !== activePointerId) {
      return;
    }

    const dx = event.clientX - startX;
    if (!dragStarted) {
      if (Math.abs(dx) < 4) {
        return;
      }
      dragStarted = true;
      element.classList.add("discourse-boards-board-container--drag-scrolling");
      try {
        element.setPointerCapture(activePointerId);
      } catch {
        // pointer capture is best-effort
      }
    }

    event.preventDefault();
    latestClientX = event.clientX;
    recordSample(event);

    if (pendingMoveFrame === null) {
      pendingMoveFrame = requestAnimationFrame(() => {
        pendingMoveFrame = null;
        element.scrollLeft = startScrollLeft - (latestClientX - startX);
      });
    }
  };

  const stopDrag = (event) => {
    if (event.pointerId !== activePointerId) {
      return;
    }

    cancelPendingMove();

    const wasDragging = dragStarted;
    if (dragStarted) {
      try {
        element.releasePointerCapture(activePointerId);
      } catch {
        // pointer capture release is best-effort
      }
      element.classList.remove(
        "discourse-boards-board-container--drag-scrolling"
      );
    }

    activePointerId = null;
    dragStarted = false;

    if (wasDragging && event.type === "pointerup") {
      startMomentum(event.timeStamp);
    }
  };

  const onClickCapture = (event) => {
    if (dragStarted) {
      event.stopPropagation();
      event.preventDefault();
    }
  };

  const onWheel = () => cancelMomentum();

  element.addEventListener("pointerdown", onPointerDown);
  element.addEventListener("pointermove", onPointerMove);
  element.addEventListener("pointerup", stopDrag);
  element.addEventListener("pointercancel", stopDrag);
  element.addEventListener("click", onClickCapture, true);
  element.addEventListener("wheel", onWheel, { passive: true });

  return () => {
    cancelMomentum();
    cancelPendingMove();
    element.removeEventListener("pointerdown", onPointerDown);
    element.removeEventListener("pointermove", onPointerMove);
    element.removeEventListener("pointerup", stopDrag);
    element.removeEventListener("pointercancel", stopDrag);
    element.removeEventListener("click", onClickCapture, true);
    element.removeEventListener("wheel", onWheel);
  };
});
