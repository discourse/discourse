import { iconHTML } from "discourse-common/lib/icon-library";
import I18n from "I18n";
import { escape } from "pretty-text/sanitizer";
import tippy from "tippy.js";

const instances = {};
const queue = [];

export function showPopup(options) {
  hidePopup(options.id);

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
    theme: "d-onboarding",

    // It must be interactive to make buttons work.
    interactive: true,

    arrow: iconHTML("tippy-rounded-arrow"),
    placement: options.placement,

    // It often happens for the reference element to be rerendered. In this
    // case, tippy must be rerendered too. Having an animation means that the
    // animation will replay over and over again.
    animation: false,

    // The `content` property below is HTML.
    allowHTML: true,

    content: `
      <div class='onboarding-popup-container'>
        <div class='onboarding-popup-title'>${escape(options.titleText)}</div>
        <div class='onboarding-popup-content'>${escape(
          options.contentText
        )}</div>
        <div class='onboarding-popup-buttons'>
          <button class="btn btn-primary btn-dismiss">${escape(
            options.primaryBtnText || I18n.t("popup.primary")
          )}</button>
          <button class="btn btn-flat btn-text btn-dismiss-all">${escape(
            options.secondaryBtnText || I18n.t("popup.secondary")
          )}</button>
        </div>
      </div>`,

    onCreate(instance) {
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

export function hidePopup(popupId) {
  const instance = instances[popupId];
  if (instance && !instance.state.isDestroyed) {
    instance.destroy();
  }
  delete instances[popupId];
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

export function showNextPopup() {
  const options = queue.shift();
  if (options) {
    showPopup(options);
  }
}
