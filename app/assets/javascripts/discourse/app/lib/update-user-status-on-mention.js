import createUserStatusMessage from "discourse/lib/user-status-message";

export function updateUserStatusOnMention(mention, status, tippyInstances) {
  removeStatus(mention);
  if (status) {
    const statusHtml = createUserStatusMessage(status, { showTooltip: true });
    tippyInstances.push(statusHtml._tippy);
    mention.appendChild(statusHtml);
  }
}

function removeStatus(mention) {
  mention.querySelector("span.user-status-message")?.remove();
}
