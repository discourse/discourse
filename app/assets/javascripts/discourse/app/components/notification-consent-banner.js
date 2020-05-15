import discourseComputed from "discourse-common/utils/decorators";
import { keyValueStore as pushNotificationKeyValueStore } from "discourse/lib/push-notifications";
import DesktopNotificationConfig from "discourse/components/desktop-notification-config";

const userDismissedPromptKey = "dismissed-prompt";

export default DesktopNotificationConfig.extend({
  @discourseComputed
  bannerDismissed: {
    set(value) {
      pushNotificationKeyValueStore.setItem(userDismissedPromptKey, value);
      return pushNotificationKeyValueStore.getItem(userDismissedPromptKey);
    },
    get() {
      return pushNotificationKeyValueStore.getItem(userDismissedPromptKey);
    }
  },

  @discourseComputed(
    "isNotSupported",
    "isEnabled",
    "bannerDismissed",
    "currentUser.any_posts"
  )
  showNotificationPromptBanner(
    isNotSupported,
    isEnabled,
    bannerDismissed,
    anyPosts
  ) {
    return (
      this.siteSettings.push_notifications_prompt &&
      !isNotSupported &&
      this.currentUser &&
      anyPosts &&
      Notification.permission !== "denied" &&
      Notification.permission !== "granted" &&
      !isEnabled &&
      !bannerDismissed
    );
  },

  actions: {
    turnon() {
      this._super(...arguments);
      this.set("bannerDismissed", true);
    },
    dismiss() {
      this.set("bannerDismissed", true);
    }
  }
});
