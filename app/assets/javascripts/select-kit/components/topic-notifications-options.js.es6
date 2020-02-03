import NotificationsButtonComponent from "select-kit/components/notifications-button";
import { topicLevels } from "discourse/lib/notification-levels";
import { computed } from "@ember/object";

export default NotificationsButtonComponent.extend({
  pluginApiIdentifiers: ["topic-notifications-options"],
  classNames: ["topic-notifications-options"],
  content: topicLevels,

  selectKitOptions: {
    i18nPrefix: "i18nPrefix",
    i18nPostfix: "i18nPostfix"
  },

  i18nPrefix: "topic.notifications",

  i18nPostfix: computed("topic.archetype", function() {
    return this.topic.archetype === "private_message" ? "_pm" : "";
  }),

  didInsertElement() {
    this._super(...arguments);

    this.appEvents.on("topic-notifications-button:changed", this, "onSelect");
  },

  willDestroyElement() {
    this._super(...arguments);

    this.appEvents.off("topic-notifications-button:changed", this, "onSelect");
  }
});
