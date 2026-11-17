const REORDER_ANIMATION = Symbol("boards-reorder-animation");

// Keep in sync with the matching CSS vars in boards-board.scss.
export const KANBAN_REORDER_DURATION = 180;
export const KANBAN_MOTION_EASING = "cubic-bezier(0.4, 0, 0.2, 1)";

export function boardsMotionEnabled() {
  if (typeof window === "undefined") {
    return false;
  }

  return !window.matchMedia?.("(prefers-reduced-motion: reduce)")?.matches;
}

export function captureCardRects(container, { skipCardIds = [] } = {}) {
  const rects = new Map();
  if (!container) {
    return rects;
  }

  const skipIds = new Set(skipCardIds.map(String));

  container
    .querySelectorAll(".discourse-boards-card")
    .forEach((cardElement) => {
      const cardId = cardElement.dataset.cardId;
      if (!cardId || skipIds.has(cardId)) {
        return;
      }

      const rect = cardElement.getBoundingClientRect();
      rects.set(cardId, {
        top: rect.top,
        left: rect.left,
      });
    });

  return rects;
}

export function animateCardReorder(
  container,
  previousRects,
  { skipCardIds = [] } = {}
) {
  if (!boardsMotionEnabled() || !container || !previousRects?.size) {
    return;
  }

  const skipIds = new Set(skipCardIds.map(String));

  container
    .querySelectorAll(".discourse-boards-card")
    .forEach((cardElement) => {
      const cardId = cardElement.dataset.cardId;
      if (!cardId || skipIds.has(cardId)) {
        return;
      }

      const previousRect = previousRects.get(cardId);
      if (!previousRect) {
        return;
      }

      const currentRect = cardElement.getBoundingClientRect();
      const deltaX = previousRect.left - currentRect.left;
      const deltaY = previousRect.top - currentRect.top;

      if (Math.abs(deltaX) < 1 && Math.abs(deltaY) < 1) {
        return;
      }

      if (!cardElement.animate) {
        return;
      }

      cardElement[REORDER_ANIMATION]?.cancel();

      const animation = cardElement.animate(
        [
          {
            transform: `translate3d(${deltaX}px, ${deltaY}px, 0)`,
          },
          {
            transform: "translate3d(0, 0, 0)",
          },
        ],
        {
          duration: KANBAN_REORDER_DURATION,
          easing: KANBAN_MOTION_EASING,
        }
      );

      cardElement[REORDER_ANIMATION] = animation;

      const clearAnimation = () => {
        if (cardElement[REORDER_ANIMATION] === animation) {
          cardElement[REORDER_ANIMATION] = null;
        }
      };

      animation.onfinish = clearAnimation;
      animation.oncancel = clearAnimation;
    });
}
