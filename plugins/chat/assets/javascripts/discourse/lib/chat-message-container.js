import { MESSAGE_CONTEXT_THREAD } from "discourse/plugins/chat/discourse/components/chat-message";

export default function chatMessageContainer(id, context) {
  let selector;

  if (context === MESSAGE_CONTEXT_THREAD) {
    selector = `.chat-thread .chat-message-container[data-id="${id}"]`;
  } else {
    selector = `.chat-live-pane .chat-message-container[data-id="${id}"]`;
  }

  return document.querySelector(selector);
}
