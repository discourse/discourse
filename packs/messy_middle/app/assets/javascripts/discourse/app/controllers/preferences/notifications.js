import Controller from "@ember/controller";
import I18n from "I18n";
import { popupAjaxError } from "discourse/lib/ajax-error";

export default Controller.extend({
  subpageTitle: I18n.t("user.preferences_nav.notifications"),

  init() {
    this._super(...arguments);

    this.saveAttrNames = [
      "muted_usernames",
      "new_topic_duration_minutes",
      "auto_track_topics_after_msecs",
      "notification_level_when_replying",
      "like_notification_frequency",
      "allow_private_messages",
      "enable_allowed_pm_users",
      "user_notification_schedule",
    ];

    this.likeNotificationFrequencies = [
      { name: I18n.t("user.like_notification_frequency.always"), value: 0 },
      {
        name: I18n.t("user.like_notification_frequency.first_time_and_daily"),
        value: 1,
      },
      { name: I18n.t("user.like_notification_frequency.first_time"), value: 2 },
      { name: I18n.t("user.like_notification_frequency.never"), value: 3 },
    ];
  },

  actions: {
    save() {
      this.set("saved", false);
      return this.model
        .save(this.saveAttrNames)
        .then(() => {
          this.set("saved", true);
        })
        .catch(popupAjaxError);
    },
  },
});
