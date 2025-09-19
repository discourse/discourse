import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { convertIconClass, isExistingIconId } from "discourse/lib/icon-library";
import { withPluginApi } from "discourse/lib/plugin-api";

function triggerAutomation(topic, button) {
  return ajax(`/automations/${button.automation_id}/topic-buttons/trigger`, {
    type: "POST",
    data: { topic_id: topic.id },
  });
}

const loadedIconPromises = new Map();

function ensureIconLoaded(iconId) {
  if (!iconId) {
    return Promise.resolve();
  }

  const normalizedId = convertIconClass(iconId);
  const sprite = document.querySelector("#svg-sprites");
  if (!sprite) {
    return Promise.resolve();
  }

  if (
    isExistingIconId(normalizedId) ||
    sprite.querySelector(`symbol#${CSS.escape(normalizedId)}`)
  ) {
    return Promise.resolve();
  }

  if (loadedIconPromises.has(iconId)) {
    return loadedIconPromises.get(iconId);
  }

  const promise = ajax("/svg-sprite/picker-search", {
    data: {
      filter: iconId,
      only_available: false,
    },
  })
    .then((icons) => {
      const match = icons.find((icon) => icon.id === iconId);

      if (!match?.symbol) {
        return;
      }

      const holderClass = "ajax-icon-holder";
      let holder = sprite.querySelector(`.${holderClass}`);

      if (!holder) {
        holder = document.createElement("div");
        holder.classList.add(holderClass);
        holder.style.display = "none";
        sprite.appendChild(holder);
      }

      if (!sprite.querySelector(`symbol#${CSS.escape(normalizedId)}`)) {
        holder.insertAdjacentHTML(
          "beforeend",
          `<svg xmlns='http://www.w3.org/2000/svg'>${match.symbol}</svg>`
        );
      }
    })
    .finally(() => {
      loadedIconPromises.delete(iconId);
    });

  loadedIconPromises.set(iconId, promise);

  return promise;
}

function reloadTopic(topic) {
  if (topic?.reload) {
    return topic.reload().catch(() => {});
  }

  return Promise.resolve();
}

export default {
  name: "discourse-automation-topic-buttons",

  initialize(owner) {
    const toasts = owner.lookup("service:toasts");

    withPluginApi((api) => {
      api.addTopicAdminMenuButton((topic) => {
        const buttons = topic.discourse_automation_topic_buttons;

        if (!buttons?.length) {
          return null;
        }

        return buttons.map((button) => {
          ensureIconLoaded(button.icon);

          return {
            className: "discourse-automation-topic-button",
            icon: button.icon,
            translatedLabel: button.label,
            action: () =>
              triggerAutomation(topic, button)
                .then(() => reloadTopic(topic))
                .then(() => {
                  if (toasts?.success) {
                    toasts.success({
                      duration: "short",
                      data: { message: button.success_message },
                    });
                  }
                })
                .catch(popupAjaxError),
          };
        });
      });
    });
  },
};
