import { UserStatusMessage } from "discourse/lib/user-status-message";

let userStatusMessages = [];

export function updateUserStatusOnMention(mention, status) {
  removeStatus(mention);
  if (status) {
    const userStatusMessage = new UserStatusMessage(status);
    userStatusMessages.push(userStatusMessage);
    mention.appendChild(userStatusMessage.html);
  }
}

export function destroyUserStatusOnMentions() {
  userStatusMessages.forEach((instance) => {
    instance.destroy();
  });
}

function removeStatus(mention) {
  mention.querySelector("span.user-status-message")?.remove();
}
