import { iconHTML } from "discourse-common/lib/icon-library";
import I18n from "I18n";
import tippy from "tippy.js";

const GLOBAL_POPUPS_KEY = "new_user_tips";
const POPUP_KEYS = ["first-notification", "topic-timeline"];

const instances = {};
const queue = [];

// Plugin used to implement actions of the two buttons
const PopupPlugin = {
  name: "popup",

  fn(instance) {
    return {
      onCreate() {
        instance.popper
          .querySelector(".btn-primary")
          .addEventListener("click", (event) => {
            const { currentUser, id } = instance.props;
            hidePopupForever(currentUser, id);
            event.preventDefault();
          });

        instance.popper
          .querySelector(".btn-flat")
          .addEventListener("click", (event) => {
            const { currentUser } = instance.props;
            hidePopupForever(currentUser, GLOBAL_POPUPS_KEY);
            event.preventDefault();
          });
      },
    };
  },
};

function getUserOptionKey(popupId) {
  return `skip_${popupId.replaceAll("-", "_")}_tips`;
}

export function showPopup(options) {
  hidePopup(options.id);

  if (
    !options.reference ||
    !options.currentUser ||
    options.currentUser.get(getUserOptionKey(options.id))
  ) {
    return;
  }

  if (Object.keys(instances).length > 0) {
    return addToQueue(options);
  }

  instances[options.id] = tippy(options.reference, {
    id: options.id,
    plugins: [PopupPlugin],

    // Current user is used to keep track of popups.
    currentUser: options.currentUser,

    // Tippy must be displayed as soon as possible and not be hidden unless
    // the user clicks on one of the two buttons.
    showOnCreate: true,
    hideOnClick: false,
    trigger: "manual",

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
        <div class='onboarding-popup-title'>${options.titleText}</div>
        <div class='onboarding-popup-content'>${options.contentText}</div>
        <div class='onboarding-popup-buttons'>
          <button class="btn btn-primary">${
            options.primaryBtnText || I18n.t("popup.primary")
          }</button>
          <button class="btn btn-flat btn-text">${
            options.secondaryBtnText || I18n.t("popup.secondary")
          }</button>
        </div>
      </div>`,
  });
}

export function hidePopup(popupId) {
  const instance = instances[popupId];
  if (instance && !instance.state.isDestroyed) {
    instance.destroy();
  }
  delete instances[popupId];
}

export function hidePopupForever(user, popupId) {
  if (!user) {
    return;
  }

  const popupIds =
    popupId === GLOBAL_POPUPS_KEY
      ? [GLOBAL_POPUPS_KEY, ...POPUP_KEYS]
      : [popupId];

  // Destroy tippy instances
  popupIds.forEach(hidePopup);

  // Update user options
  if (!user.user_option) {
    user.set("user_option", {});
  }

  const userOptionKeys = popupIds.map(getUserOptionKey);
  let updates = false;
  userOptionKeys.forEach((key) => {
    if (!user.get(key)) {
      user.set(key, true);
      user.set(`user_option.${key}`, true);
      updates = true;
    }
  });

  // Show next popup in queue
  showNextPopup();

  return updates ? user.save(userOptionKeys) : Promise.resolve();
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

function showNextPopup() {
  const options = queue.shift();
  if (options) {
    showPopup(options);
  }
}
