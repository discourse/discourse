import { isTesting } from "discourse-common/config/environment";
import { iconHTML } from "discourse-common/lib/icon-library";
import I18n from "I18n";
import { escape } from "pretty-text/sanitizer";
import tippy from "tippy.js";

const TIPPY_DELAY = isTesting() ? 0 : 500;

const instancesMap = {};
window.instancesMap = instancesMap;

export function showUserTip(options) {
  let instance = instancesMap[options.id];
  if (instance) {
    if (instance.reference === options.reference) {
      if (instance.destroyTimeout) {
        clearTimeout(instance.destroyTimeout);
      }
      return;
    }

    instance.destroy();
    delete instancesMap[options.id];
  }

  if (!options.reference) {
    return;
  }

  instancesMap[options.id] = tippy(options.reference, {
    hideOnClick: false,
    trigger: "manual",
    theme: "user-tip",
    zIndex: "", // reset z-index
    duration: TIPPY_DELAY,

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
  showNextUserTip();
}

export function hideUserTip(userTipId, force = false) {
  const instance = instancesMap[userTipId];
  if (!instance) {
    return;
  }

  if (force) {
    instance.destroy();
    delete instancesMap[userTipId];
    showNextUserTip();
  } else if (!instance.destroyTimeout) {
    instance.destroyTimeout = setTimeout(
      () => hideUserTip(userTipId, true),
      TIPPY_DELAY
    );
  }
}

export function hideAllUserTips() {
  Object.keys(instancesMap).forEach((userTipId) => {
    instancesMap[userTipId].destroy();
    delete instancesMap[userTipId];
  });
}

export function showNextUserTip() {
  const instances = Object.values(instancesMap);

  let index = instances.findIndex((instance) => {
    const position = instance.reference.getBoundingClientRect();
    const width = window.innerWidth || document.documentElement.clientWidth;
    const height = window.innerHeight || document.documentElement.clientHeight;
    return (
      position.top >= 0 &&
      position.left >= 0 &&
      position.bottom <= height &&
      position.right <= width
    );
  });

  const newInstance = instances[index === -1 ? 0 : index];
  if (!newInstance) {
    return;
  }

  instances.forEach((instance) => {
    if (instance === newInstance) {
      instance.showTimeout = setTimeout(() => {
        if (!instance.state.isDestroyed) {
          instance.show();
        }
      }, TIPPY_DELAY);
    } else {
      instance.hide();
    }
  });
}
