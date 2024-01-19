import { schedule } from "@ember/runloop";

export function scrollListToBottom(list) {
  list.scrollTo({ top: 0, behavior: "auto" });
}

export function scrollListToTop(list) {
  list.scrollTo({ top: -list.scrollHeight, behavior: "auto" });
}

export function scrollListToMessage(
  list,
  message,
  opts = { highlight: false, position: "start", autoExpand: false }
) {
  return;
  if (!message) {
    return;
  }

  if (message?.deletedAt && opts.autoExpand) {
    message.expanded = true;
  }

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

    console.log(messageEl);

    messageEl.scrollIntoView({
      behavior: "auto",
      block: opts.position || "center",
    });

    // Calculate the total height of the sticky elements
    let stickyElementsHeight = 0;

    // Adjust the scroll position
    window.scrollBy(0, 100);
  });
}
