import { UserStatusMessage } from "discourse/lib/user-status-message";

let userStatusMessages = [];

export function initUserStatusHtml(owner, users) {
  (users || []).forEach((user, index) => {
    if (user.status) {
      user.index = index;
      const userStatusMessage = new UserStatusMessage(owner, user.status, {
        showDescription: true,
      });
      user.statusHtml = userStatusMessage.html;
      userStatusMessages.push(userStatusMessage);
    }
  });
}

export function renderUserStatusHtml(options) {
  const users = document.querySelectorAll(".autocomplete.ac-user li");
  users.forEach((user) => {
    const index = user.dataset.index;
    const statusHtml = options.find(function (el) {
      return el.index === parseInt(index, 10);
    })?.statusHtml;
    if (statusHtml) {
      user.querySelector(".user-status").replaceWith(statusHtml);
    }
  });
}

export function destroyUserStatuses() {
  userStatusMessages.forEach((instance) => {
    instance.destroy();
  });
  userStatusMessages = [];
}
