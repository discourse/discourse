import { default as computed } from "ember-addons/ember-computed-decorators";

import { keyValueStore as pushNotificationKeyValueStore } from "discourse/lib/push-notifications";

import { default as DesktopNotificationConfig } from "discourse/components/desktop-notification-config";

const userDismissedPromptKey = "dismissed-prompt";

export default DesktopNotificationConfig.extend({
  @computed
  bannerDismissed: {
    set(value) {
      pushNotificationKeyValueStore.setItem(userDismissedPromptKey, value);
      return pushNotificationKeyValueStore.getItem(userDismissedPromptKey);
    },
    get() {
      return pushNotificationKeyValueStore.getItem(userDismissedPromptKey);
    }
  },

  @computed(
    "isNotSupported",
    "isEnabled",
    "bannerDismissed",
    "currentUser.reply_count",
    "currentUser.topic_count"
  )
  showNotificationPromptBanner(
    isNotSupported,
    isEnabled,
    bannerDismissed,
    replyCount,
    topicCount
  ) {
    return (
      this.siteSettings.push_notifications_prompt &&
      !isNotSupported &&
      this.currentUser &&
      replyCount + topicCount > 0 &&
      Notification.permission !== "denied" &&
      Notification.permission !== "granted" &&
      !isEnabled &&
      !bannerDismissed
    );
  },

  actions: {
    turnon() {
      this._super();
      this.set("bannerDismissed", true);
    },
    dismiss() {
      this.set("bannerDismissed", true);
    }
  }
});
