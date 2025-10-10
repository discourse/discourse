import { next, schedule } from "@ember/runloop";

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
