import { checkMessageBottomVisibility } from "discourse/plugins/chat/discourse/lib/check-message-visibility";

export default function firstVisibleMessageId(container) {
  let _found;
  const messages = container.querySelectorAll(
    ":scope .chat-messages-container > [data-id]"
  );

  for (let i = messages.length - 1; i >= 0; i--) {
    const message = messages[i];

    if (checkMessageBottomVisibility(container, message)) {
      _found = message;
      break;
    }
  }

  const id = _found?.dataset?.id;
  return id ? parseInt(id, 10) : null;
}
