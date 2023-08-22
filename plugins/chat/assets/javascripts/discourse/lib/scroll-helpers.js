import { schedule } from "@ember/runloop";
import { stackingContextFix } from "discourse/plugins/chat/discourse/lib/chat-ios-hacks";

export function scrollListToBottom(list) {
  stackingContextFix(list, () => {
    list.scrollTo({ top: 0, behavior: "auto" });
  });
}

export function scrollListToTop(list) {
  stackingContextFix(list, () => {
    list.scrollTo({ top: -list.scrollHeight, behavior: "auto" });
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

    stackingContextFix(list, () => {
      messageEl.scrollIntoView({
        behavior: "auto",
        block: opts.position || "center",
      });
    });
  });
}
