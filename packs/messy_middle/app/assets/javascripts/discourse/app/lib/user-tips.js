import { iconHTML } from "discourse-common/lib/icon-library";
import I18n from "I18n";
import { escape } from "pretty-text/sanitizer";
import tippy from "tippy.js";

const instances = {};
const queue = [];

export function showUserTip(options) {
  hideUserTip(options.id);

  if (!options.reference) {
    return;
  }

  if (Object.keys(instances).length > 0) {
    return addToQueue(options);
  }

  instances[options.id] = tippy(options.reference, {
    // Tippy must be displayed as soon as possible and not be hidden unless
    // the user clicks on one of the two buttons.
    showOnCreate: true,
    hideOnClick: false,
    trigger: "manual",
    theme: "user-tips",
    zIndex: "",

    // It must be interactive to make buttons work.
    interactive: true,

    arrow: iconHTML("tippy-rounded-arrow"),
    placement: options.placement,
    appendTo: options.appendTo,

    // It often happens for the reference element to be rerendered. In this
    // case, tippy must be rerendered too. Having an animation means that the
    // animation will replay over and over again.
    animation: false,

    // The `content` property below is HTML.
    allowHTML: true,

    content: `
      <div class='user-tip-container'>
        <div class='user-tip-title'>${escape(options.titleText)}</div>
        <div class='user-tip-content'>${escape(options.contentText)}</div>
        <div class='user-tip-buttons'>
          <button class="btn btn-primary btn-dismiss">${escape(
            options.primaryBtnText || I18n.t("user_tips.primary")
          )}</button>
          <button class="btn btn-flat btn-text btn-dismiss-all">${escape(
            options.secondaryBtnText || I18n.t("user_tips.secondary")
          )}</button>
        </div>
      </div>`,

    onCreate(instance) {
      instance.popper.classList.add("user-tip");

      instance.popper
        .querySelector(".btn-dismiss")
        .addEventListener("click", (event) => {
          options.onDismiss();
          event.preventDefault();
        });

      instance.popper
        .querySelector(".btn-dismiss-all")
        .addEventListener("click", (event) => {
          options.onDismissAll();
          event.preventDefault();
        });
    },
  });
}

export function hideUserTip(userTipId) {
  const instance = instances[userTipId];
  if (instance && !instance.state.isDestroyed) {
    instance.destroy();
  }
  delete instances[userTipId];

  const index = queue.findIndex((userTip) => userTip.id === userTipId);
  if (index > -1) {
    queue.splice(index, 1);
  }
}

export function hideAllUserTips() {
  Object.keys(instances).forEach(hideUserTip);
}

function addToQueue(options) {
  for (let i = 0; i < queue.size; ++i) {
    if (queue[i].id === options.id) {
      queue[i] = options;
      return;
    }
  }

  queue.push(options);
}

export function showNextUserTip() {
  const options = queue.shift();
  if (options) {
    showUserTip(options);
  }
}
