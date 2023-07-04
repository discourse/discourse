import { isTesting } from "discourse-common/config/environment";
import { iconHTML } from "discourse-common/lib/icon-library";
import I18n from "I18n";
import { escape } from "pretty-text/sanitizer";
import tippy from "tippy.js";

const TIPPY_DELAY = 500;

const instances = {};
const queue = [];

function addToQueue(options) {
  for (let i = 0; i < queue.size; ++i) {
    if (queue[i].id === options.id) {
      queue[i] = options;
      return;
    }
  }

  queue.push(options);
}

function removeFromQueue(userTipId) {
  const index = queue.findIndex((userTip) => userTip.id === userTipId);
  if (index !== -1) {
    queue.splice(index, 1);
  }
}

export function showUserTip(options) {
  let instance = instances[options.id];
  if (instance) {
    if (instance.reference === options.reference) {
      if (instance.destroyTimeout) {
        clearTimeout(instance.destroyTimeout);
      }
      return;
    }

    instance.destroy();
    delete instances[options.id];
  }

  if (!options.reference) {
    return;
  }

  if (options.content) {
    // Remove element from DOM to hide it
    options.content.remove();
  }

  if (Object.keys(instances).length > 0) {
    return addToQueue(options);
  } else {
    removeFromQueue(options.id);
  }

  instances[options.id] = tippy(options.reference, {
    showOnCreate: true,
    hideOnClick: false,
    trigger: "manual",
    theme: "user-tip",
    zIndex: "", // reset z-index
    delay: isTesting() ? 0 : TIPPY_DELAY,

    arrow: iconHTML("tippy-rounded-arrow"),
    placement: options.placement,
    appendTo: options.appendTo,

    interactive: true, // for buttons in content
    allowHTML: true,

    content:
      options.content ||
      `<div class='user-tip__container'>
        <div class='user-tip__title'>${escape(options.titleText)}</div>
        <div class='user-tip__content'>${escape(options.contentText)}</div>
        <div class='user-tip__buttons'>
          <button class="btn btn-primary btn-dismiss">${escape(
            options.primaryBtnText || I18n.t("user_tips.primary")
          )}</button>
          <button class="btn btn-flat btn-text btn-dismiss-all">${escape(
            options.secondaryBtnText || I18n.t("user_tips.secondary")
          )}</button>
        </div>
      </div>`,

    onCreate(tippyInstance) {
      // Used to set correct z-index property on root tippy element
      tippyInstance.popper.classList.add("user-tip");

      tippyInstance.popper
        .querySelector(".btn-dismiss")
        .addEventListener("click", (event) => {
          options.onDismiss();
          event.preventDefault();
        });

      tippyInstance.popper
        .querySelector(".btn-dismiss-all")
        .addEventListener("click", (event) => {
          options.onDismissAll();
          event.preventDefault();
        });
    },
  });
}

export function hideUserTip(userTipId, now = false) {
  removeFromQueue(userTipId);

  const instance = instances[userTipId];
  if (!instance) {
    return;
  }

  if (now) {
    instance.destroy();
    delete instances[userTipId];
  } else if (!instance.destroyTimeout) {
    instance.destroyTimeout = setTimeout(() => {
      const tippyInstance = instances[userTipId];
      if (tippyInstance) {
        tippyInstance.destroy();
        delete instances[userTipId];
      }
    }, TIPPY_DELAY);
  }
}

export function hideAllUserTips() {
  Object.keys(instances).forEach((userTipId) => hideUserTip(userTipId, true));
}

export function showNextUserTip() {
  let index = queue.findIndex((options) => {
    const position = options.reference.getBoundingClientRect();
    const width = window.innerWidth || document.documentElement.clientWidth;
    const height = window.innerHeight || document.documentElement.clientHeight;
    return (
      position.top >= 0 &&
      position.left >= 0 &&
      position.bottom <= height &&
      position.right <= width
    );
  });

  if (index === -1) {
    index = 0;
  }

  if (queue.length > index) {
    const options = queue.splice(index, 1)[0];
    showUserTip(options);
  }
}
