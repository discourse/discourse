import discourseComputed, {
  bind,
  observes,
} from "discourse-common/utils/decorators";
import Service from "@ember/service";
import I18n from "I18n";
import { autoUpdatingRelativeAge } from "discourse/lib/formatter";
import getURL from "discourse-common/lib/get-url";
import { htmlSafe } from "@ember/template";
import { isEmpty } from "@ember/utils";
import { readOnly } from "@ember/object/computed";

const LOGS_NOTICE_KEY = "logs-notice-text";

export default Service.extend({
  text: "",

  isAdmin: readOnly("currentUser.admin"),

  init() {
    this._super(...arguments);

    if (
      this.siteSettings.alert_admins_if_errors_per_hour === 0 &&
      this.siteSettings.alert_admins_if_errors_per_minute === 0
    ) {
      return;
    }

    const text = this.keyValueStore.getItem(LOGS_NOTICE_KEY);
    if (text) {
      this.set("text", text);
    }

    this.messageBus.subscribe("/logs_error_rate_exceeded", this.onLogRateLimit);
  },

  willDestroy() {
    this._super(...arguments);

    this.messageBus.unsubscribe(
      "/logs_error_rate_exceeded",
      this.onLogRateLimit
    );
  },

  @bind
  onLogRateLimit(data) {
    const { duration, rate } = data;
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
        relativeAge: autoUpdatingRelativeAge(new Date(data.publish_at * 1000)),
        rate,
        limit: siteSettingLimit,
        url: getURL("/logs"),
      })
    );
  },

  @discourseComputed("text")
  isEmpty(text) {
    return isEmpty(text);
  },

  @discourseComputed("text")
  message(text) {
    return htmlSafe(text);
  },

  @discourseComputed("isEmpty", "isAdmin")
  hidden(thisIsEmpty, isAdmin) {
    return !isAdmin || thisIsEmpty;
  },

  @observes("text")
  _updateKeyValueStore() {
    this.keyValueStore.setItem(LOGS_NOTICE_KEY, this.text);
  },
});
