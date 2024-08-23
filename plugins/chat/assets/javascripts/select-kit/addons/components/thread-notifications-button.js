import { classNames } from "@ember-decorators/component";
import NotificationsButtonComponent from "select-kit/components/notifications-button";
import {
  pluginApiIdentifiers,
  selectKitOptions,
} from "select-kit/components/select-kit";
import { threadNotificationButtonLevels } from "discourse/plugins/chat/discourse/lib/chat-notification-levels";

@classNames("thread-notifications-button")
@selectKitOptions({
  i18nPrefix: "chat.thread.notifications",
  showFullTitle: false,
  btnCustomClasses: "btn-flat",
})
@pluginApiIdentifiers("thread-notifications-button")
export default class ThreadNotificationsButton extends NotificationsButtonComponent {
  content = threadNotificationButtonLevels;
}
