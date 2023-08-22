import createDTooltip from "discourse/lib/d-tooltip";
import { emojiUnescape } from "discourse/lib/text";
import { escapeExpression } from "discourse/lib/utilities";
import { until } from "discourse/lib/formatter";
import User from "discourse/models/user";

function getUntil(endsAt) {
  const currentUser = User.current();

  const timezone = currentUser
    ? currentUser.user_option?.timezone
    : moment.tz.guess();

  return until(endsAt, timezone, currentUser?.locale);
}

function getEmoji(emojiName) {
  const emoji = escapeExpression(`:${emojiName}:`);
  return emojiUnescape(emoji, {
    skipTitle: true,
  });
}

function attachTooltip(target, status) {
  const content = document.createElement("div");
  content.classList.add("user-status-message-tooltip");
  content.innerHTML = getEmoji(status.emoji);

  const tooltipDescription = document.createElement("span");
  tooltipDescription.classList.add("user-status-tooltip-description");
  tooltipDescription.innerText = status.description;
  content.appendChild(tooltipDescription);

  if (status.ends_at) {
    const untilElement = document.createElement("div");
    untilElement.classList.add("user-status-tooltip-until");
    untilElement.innerText = getUntil(status.ends_at);
    content.appendChild(untilElement);
  }
  createDTooltip(target, content);
}

export default function createUserStatusMessage(status, opts) {
  const userStatusMessage = document.createElement("span");
  userStatusMessage.classList.add("user-status-message");
  if (opts?.class) {
    userStatusMessage.classList.add(opts.class);
  }
  userStatusMessage.innerHTML = getEmoji(status.emoji);

  if (opts?.showDescription) {
    const messageDescription = document.createElement("span");
    messageDescription.classList.add("user-status-message-description");
    messageDescription.innerText = status.description;
    userStatusMessage.appendChild(messageDescription);
  }

  if (opts?.showTooltip) {
    attachTooltip(userStatusMessage, status);
  }
  return userStatusMessage;
}
