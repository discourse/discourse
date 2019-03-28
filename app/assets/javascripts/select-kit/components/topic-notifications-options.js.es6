import NotificationOptionsComponent from "select-kit/components/notifications-button";
import {
  default as computed,
  on
} from "ember-addons/ember-computed-decorators";
import { topicLevels } from "discourse/lib/notification-levels";

export default NotificationOptionsComponent.extend({
  pluginApiIdentifiers: ["topic-notifications-options"],
  classNames: "topic-notifications-options",
  content: topicLevels,
  i18nPrefix: "topic.notifications",
  allowInitialValueMutation: false,

  @computed("topic.archetype")
  i18nPostfix(archetype) {
    return archetype === "private_message" ? "_pm" : "";
  },

  _changed(msg) {
    if (this.get("computedValue") !== msg.id) {
      this.get("topic.details").updateNotifications(msg.id);
    }
  },

  @on("didInsertElement")
  _bindGlobalLevelChanged() {
    this.appEvents.on("topic-notifications-button:changed", this, "_changed");
  },

  @on("willDestroyElement")
  _unbindGlobalLevelChanged() {
    this.appEvents.off("topic-notifications-button:changed", this, "_changed");
  },

  mutateValue(value) {
    if (value !== this.get("value")) {
      this.get("topic.details").updateNotifications(value);
    }
  },

  deselect() {}
});
