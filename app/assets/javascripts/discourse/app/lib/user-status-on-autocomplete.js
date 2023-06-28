import createUserStatusMessage from "discourse/lib/user-status-message";

export function initUserStatusHtml(users) {
  let instances = [];
  (users || []).forEach((user, index) => {
    if (user.status) {
      user.index = index;
      user.statusHtml = createUserStatusMessage(user.status, {
        showTooltip: true,
        showDescription: true,
      });
      instances.push(user.statusHtml._tippy);
    }
  });
  return instances;
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
