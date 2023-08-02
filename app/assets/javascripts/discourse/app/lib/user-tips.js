import { isTesting } from "discourse-common/config/environment";
import { iconHTML } from "discourse-common/lib/icon-library";
import I18n from "I18n";
import { escape } from "pretty-text/sanitizer";
import tippy from "tippy.js";
import isElementInViewport from "discourse/lib/is-element-in-viewport";

const TIPPY_DELAY = 500;

const instancesMap = {};
window.instancesMap = instancesMap;

function destroyInstance(instance) {
  if (instance.showTimeout) {
    clearTimeout(instance.showTimeout);
    instance.showTimeout = null;
  }

  if (instance.destroyTimeout) {
    clearTimeout(instance.destroyTimeout);
    instance.destroyTimeout = null;
  }

  instance.destroy();
}

function cancelDestroyInstance(instance) {
  if (instance.destroyTimeout) {
    clearTimeout(instance.destroyTimeout);
    instance.destroyTimeout = null;
  }
}

function showInstance(instance) {
  if (isTesting()) {
    instance.show();
  } else if (!instance.showTimeout) {
    instance.showTimeout = setTimeout(() => {
      instance.showTimeout = null;
      if (!instance.state.isDestroyed) {
        instance.show();
      }
    }, TIPPY_DELAY);
  }
}

function hideInstance(instance) {
  clearTimeout(instance.showTimeout);
  instance.showTimeout = null;
  instance.hide();
}

export function showUserTip(options) {
  // Find if a similar instance has been scheduled for destroying recently
  // and cancel that
  let instance = instancesMap[options.id];
  if (instance) {
    if (instance.reference === options.reference) {
      return cancelDestroyInstance(instance);
    } else {
      destroyInstance(instance);
      delete instancesMap[options.id];
    }
  }

  if (!options.reference) {
    return;
  }

  let buttonText = escape(I18n.t(options.buttonLabel || "user_tips.button"));
  if (options.buttonIcon) {
    buttonText = `${iconHTML(options.buttonIcon)} ${buttonText}`;
  }

  instancesMap[options.id] = tippy(options.reference, {
    hideOnClick: false,
    trigger: "manual",
    theme: "user-tip",
    zIndex: "", // reset z-index to use inherited value from the parent
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
        <div class='user-tip__content'>${
          options.contentHtml || escape(options.contentText)
        }</div>
        <div class='user-tip__buttons'>
          <button class="btn btn-primary">${buttonText}</button>
        </div>
      </div>`,

    onCreate(tippyInstance) {
      // Used to set correct z-index property on root tippy element
      tippyInstance.popper.classList.add("user-tip");

      tippyInstance.popper
        .querySelector(".btn")
        .addEventListener("click", (event) => {
          options.onDismiss?.();
          event.preventDefault();
        });
    },
  });

  showNextUserTip();
}

export function hideUserTip(userTipId, force = false) {
  // Tippy instances are not destroyed immediately because sometimes there
  // user tip is recreated immediately. This happens when Ember components
  // are re-rendered because a parent component has changed

  const instance = instancesMap[userTipId];
  if (!instance) {
    return;
  }

  if (force) {
    destroyInstance(instance);
    delete instancesMap[userTipId];
    showNextUserTip();
  } else if (!instance.destroyTimeout) {
    instance.destroyTimeout = setTimeout(() => {
      destroyInstance(instancesMap[userTipId]);
      delete instancesMap[userTipId];
      showNextUserTip();
    }, TIPPY_DELAY);
  }
}

export function hideAllUserTips() {
  Object.keys(instancesMap).forEach((userTipId) => {
    destroyInstance(instancesMap[userTipId]);
    delete instancesMap[userTipId];
  });
}

export function showNextUserTip() {
  const instances = Object.values(instancesMap);

  // Return early if a user tip is already visible and it is in viewport
  if (
    instances.find(
      (instance) =>
        instance.state.isVisible && isElementInViewport(instance.reference)
    )
  ) {
    return;
  }

  // Otherwise, try to find a user tip in the viewport
  const idx = instances.findIndex((instance) =>
    isElementInViewport(instance.reference)
  );

  // If no instance was found, select first user tip
  const newInstance = instances[idx === -1 ? 0 : idx];

  // Show only selected instance and hide all the other ones
  instances.forEach((instance) => {
    if (instance === newInstance) {
      showInstance(instance);
    } else {
      hideInstance(instance);
    }
  });
}
