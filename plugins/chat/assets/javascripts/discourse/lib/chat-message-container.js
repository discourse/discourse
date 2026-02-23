import { MESSAGE_CONTEXT_THREAD } from "discourse/plugins/chat/discourse/components/chat-message";

export const MESSAGE_CONTEXT_PINNED = "pinned";

export default function chatMessageContainer(id, context) {
  let selector;

  if (context === MESSAGE_CONTEXT_THREAD) {
    selector = `.chat-thread .chat-message-container[data-id="${id}"]`;
  } else if (context === MESSAGE_CONTEXT_PINNED) {
    selector = `.chat-pinned-messages-list .chat-message-container[data-id="${id}"]`;
  } else {
    selector = `.chat-channel .chat-message-container[data-id="${id}"]`;
  }

  return document.querySelector(selector);
}
