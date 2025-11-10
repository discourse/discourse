import { guidFor } from "@ember/object/internals";
import { UserStatusMessage } from "discourse/lib/user-status-message";

const userStatusMessages = {};

export function updateUserStatusOnMention(owner, mention, status) {
  removeStatus(mention);
  if (status) {
    const userStatusMessage = new UserStatusMessage(owner, status);
    userStatusMessages[guidFor(mention)] = userStatusMessage;
    mention.appendChild(userStatusMessage.html);
  }
}

export function destroyUserStatusOnMentions() {
  Object.values(userStatusMessages).forEach((instance) => {
    instance.destroy();
  });
}

function removeStatus(mention) {
  userStatusMessages[guidFor(mention)]?.destroy();
  mention.querySelector("span.user-status-message")?.remove();
}
