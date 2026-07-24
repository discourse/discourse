import { withPluginApi } from "discourse/lib/plugin-api";
import I18n, { i18n } from "discourse-i18n";

const EVENT_ICON = "calendar-day";

function initializeCreateEventComposerAction(api, eventComposer) {
  api.addComposerAction({
    id: "create_event",
    label: "discourse_post_event.composer_actions.create_event.label",
    description: "discourse_post_event.composer_actions.create_event.desc",
    icon: EVENT_ICON,
    condition: (component) => {
      const composer = component.composerModel;
      return eventComposer.eligible(composer) && !composer.creatingEvent;
    },
    action: (composer) => eventComposer.enterEventMode(composer),
  });

  api.addComposerAction({
    id: "create_regular_topic",
    label: "discourse_post_event.composer_actions.create_topic.label",
    description: "discourse_post_event.composer_actions.create_topic.desc",
    icon: "plus",
    condition: (component) => {
      const composer = component.composerModel;
      return eventComposer.eligible(composer) && composer.creatingEvent;
    },
    action: (composer) => eventComposer.exitEventMode(composer),
  });

  api.customizeComposerText({
    actionTitle(model) {
      if (!model.creatingEvent) {
        return;
      }
      const key = "discourse_post_event.composer.action_title";
      if (I18n.lookup(key) !== undefined) {
        return i18n(key);
      }
    },
    saveLabel(model) {
      if (model.creatingEvent) {
        return "discourse_post_event.composer.create_event_button";
      }
    },
    saveIcon(model) {
      if (model.creatingEvent) {
        return EVENT_ICON;
      }
    },
    titlePlaceholder(model) {
      if (model.creatingEvent) {
        return "discourse_post_event.composer.event_title_placeholder";
      }
    },
  });
}

export default {
  name: "add-create-event-composer-action",
  initialize(container) {
    const siteSettings = container.lookup("service:site-settings");
    if (!siteSettings.discourse_post_event_enabled) {
      return;
    }
    const eventComposer = container.lookup("service:create-event-composer");
    withPluginApi((api) =>
      initializeCreateEventComposerAction(api, eventComposer)
    );
  },
};
