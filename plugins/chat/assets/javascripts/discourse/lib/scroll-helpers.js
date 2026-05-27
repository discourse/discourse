import { next, schedule } from "@ember/runloop";

/**
 * Tracks pending scroll adjustments to handle re-entrant calls.
 * Maps scroller elements to their captured state.
 *
 * @type {WeakMap<HTMLElement, { scrollTop: number; scrollHeight: number }>}
 */
const pendingAdjustments = new WeakMap();

/**
 * Prevent viewport drift when the list grows while scrolled away from bottom.
 *
 * Our chat scroller uses flex-direction: column-reverse for bottom-origin scroll.
 * Appending content can shift the viewport unless we compensate for height changes.
 *
 * @param {HTMLElement | null} scroller - The scrollable container
 * @param {Function} callback - Function that modifies the list content
 */
export function maintainScrollPosition(scroller, callback) {
  if (!scroller) {
    callback?.();
    return;
  }

  const existing = pendingAdjustments.get(scroller);
  if (existing) {
    existing.scrollTop = scroller.scrollTop;
    callback?.();
    return;
  }

  const state = {
    scrollTop: scroller.scrollTop,
    scrollHeight: scroller.scrollHeight,
  };

  pendingAdjustments.set(scroller, state);
  callback?.();

  schedule("afterRender", () => {
    const captured = pendingAdjustments.get(scroller);
    pendingAdjustments.delete(scroller);

    if (!captured || !scroller.isConnected) {
      return;
    }

    const heightDiff = scroller.scrollHeight - captured.scrollHeight;
    if (!heightDiff || heightDiff < 1) {
      return;
    }

    scroller.scrollTop = captured.scrollTop - heightDiff;
  });
}

export async function scrollListToBottom(list) {
  await new Promise((resolve) => {
    list.scrollTo({ top: 0, behavior: "auto" });
    next(resolve);
  });
}

export async function scrollListToTop(list) {
  await new Promise((resolve) => {
    list.scrollTo({ top: -list.scrollHeight, behavior: "auto" });
    next(resolve);
  });
}

export function scrollListToMessage(
  list,
  message,
  opts = { highlight: false, position: "start", autoExpand: false }
) {
  if (!message) {
    return;
  }

  if (message?.deletedAt && opts.autoExpand) {
    message.expanded = true;
  }

  next(() => {
    schedule("afterRender", () => {
      const messageEl = list.querySelector(
        `.chat-message-container[data-id='${message.id}']`
      );

      if (!messageEl) {
        return;
      }

      if (opts.highlight) {
        message.highlight();
      }

      messageEl.scrollIntoView({
        behavior: "auto",
        block: opts.position || "center",
      });
    });
  });
}
