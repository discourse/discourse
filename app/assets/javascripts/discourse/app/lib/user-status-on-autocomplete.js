import createUserStatusMessage from "discourse/lib/user-status-message";

let tippyInstances = [];

export function initUserStatusHtml(users) {
  (users || []).forEach((user, index) => {
    if (user.status) {
      user.index = index;
      user.statusHtml = createUserStatusMessage(user.status, {
        showTooltip: true,
        showDescription: true,
      });
      tippyInstances.push(user.statusHtml._tippy);
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

export function destroyTippyInstances() {
  tippyInstances.forEach((instance) => {
    instance.destroy();
  });
  tippyInstances = [];
}
