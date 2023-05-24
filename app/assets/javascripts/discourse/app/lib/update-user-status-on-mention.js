import { escapeExpression } from "discourse/lib/utilities";
import { emojiUnescape } from "discourse/lib/text";
import { until } from "discourse/lib/formatter";

export function updateUserStatusOnMention(mention, status, currentUser) {
  removeStatus(mention);
  if (status) {
    const html = statusHtml(status, currentUser);
    mention.insertAdjacentHTML("beforeend", html);
  }
}

function removeStatus(mention) {
  mention.querySelector("img.user-status")?.remove();
}

function statusHtml(status, currentUser) {
  const emoji = escapeExpression(`:${status.emoji}:`);
  return emojiUnescape(emoji, {
    class: "user-status",
    title: statusTitle(status, currentUser),
  });
}

function statusTitle(status, currentUser) {
  if (!status.ends_at) {
    return status.description;
  }

  const timezone = currentUser
    ? currentUser.user_option?.timezone
    : moment.tz.guess();

  const until_ = until(status.ends_at, timezone, currentUser?.locale);
  return escapeExpression(`${status.description} ${until_}`);
}
