import discourseComputed, { observes } from "discourse-common/utils/decorators";
import EmberObject from "@ember/object";
import I18n from "I18n";
import { autoUpdatingRelativeAge } from "discourse/lib/formatter";
import getURL from "discourse-common/lib/get-url";
import { htmlSafe } from "@ember/template";
import { isEmpty } from "@ember/utils";

const LOGS_NOTICE_KEY = "logs-notice-text";

const CHANNEL = "/logs_error_rate_exceeded";

export default EmberObject.extend({
  text: "",

  init() {
    this._super();

    if (!this.isActivated) {
      return;
    }

    const text = this.keyValueStore.getItem(LOGS_NOTICE_KEY);
    if (text) {
      this.set("text", text);
    }

    this.messageBus.subscribe(CHANNEL, (data) => {
      const duration = data.duration;
      const rate = data.rate;
      let siteSettingLimit = 0;

      if (duration === "minute") {
        siteSettingLimit = this.siteSettings.alert_admins_if_errors_per_minute;
      } else if (duration === "hour") {
        siteSettingLimit = this.siteSettings.alert_admins_if_errors_per_hour;
      }

      let translationKey = rate === siteSettingLimit ? "reached" : "exceeded";
      translationKey += `_${duration}_MF`;

      this.set(
        "text",
        I18n.messageFormat(`logs_error_rate_notice.${translationKey}`, {
          relativeAge: autoUpdatingRelativeAge(
            new Date(data.publish_at * 1000)
          ),
          rate,
          limit: siteSettingLimit,
          url: getURL("/logs"),
        })
      );
    });
  },

  willDestroy() {
    this._super();
    this.messageBus.unsubscribe(CHANNEL);
  },

  @discourseComputed("text")
  isEmpty(text) {
    return isEmpty(text);
  },

  @discourseComputed("text")
  message(text) {
    return htmlSafe(text);
  },

  @discourseComputed("currentUser")
  isAdmin(currentUser) {
    return currentUser && currentUser.admin;
  },

  @discourseComputed("isEmpty", "isAdmin")
  hidden(thisIsEmpty, isAdmin) {
    return !isAdmin || thisIsEmpty;
  },

  @observes("text")
  _updateKeyValueStore() {
    this.keyValueStore.setItem(LOGS_NOTICE_KEY, this.text);
  },

  @discourseComputed(
    "siteSettings.alert_admins_if_errors_per_hour",
    "siteSettings.alert_admins_if_errors_per_minute"
  )
  isActivated(errorsPerHour, errorsPerMinute) {
    return errorsPerHour > 0 || errorsPerMinute > 0;
  },
});
