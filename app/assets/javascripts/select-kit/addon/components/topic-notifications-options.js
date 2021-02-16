import NotificationsButtonComponent from "select-kit/components/notifications-button";
import { computed } from "@ember/object";
import { topicLevels } from "discourse/lib/notification-levels";

export default NotificationsButtonComponent.extend({
  pluginApiIdentifiers: ["topic-notifications-options"],
  classNames: ["topic-notifications-options"],
  content: topicLevels,

  selectKitOptions: {
    i18nPrefix: "topic.notifications",
    i18nPostfix: "i18nPostfix",
    showCaret: true,
  },

  i18nPostfix: computed("topic.archetype", function () {
    return this.topic.archetype === "private_message" ? "_pm" : "";
  }),
});
