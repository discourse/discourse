import NotificationsButtonComponent from "select-kit/components/notifications-button";
import { threadLevels } from "discourse/plugins/chat/discourse/lib/chat-notification-levels";

export default NotificationsButtonComponent.extend({
  pluginApiIdentifiers: ["thread-notifications-button"],
  classNames: ["thread-notifications-button"],
  content: threadLevels,

  selectKitOptions: {
    i18nPrefix: "chat.thread.notifications",
    showFullTitle: false,
    btnCustomClasses: "btn-flat",
  },
});
