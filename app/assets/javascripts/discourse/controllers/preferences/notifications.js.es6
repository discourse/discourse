import Controller from "@ember/controller";
import PreferencesTabController from "discourse/mixins/preferences-tab-controller";
import { NotificationLevels } from "discourse/lib/notification-levels";
import { popupAjaxError } from "discourse/lib/ajax-error";

export default Controller.extend(PreferencesTabController, {
  init() {
    this._super(...arguments);

    this.saveAttrNames = [
      "muted_usernames",
      "ignored_usernames",
      "new_topic_duration_minutes",
      "auto_track_topics_after_msecs",
      "notification_level_when_replying",
      "like_notification_frequency",
      "allow_private_messages"
    ];

    this.likeNotificationFrequencies = [
      { name: I18n.t("user.like_notification_frequency.always"), value: 0 },
      {
        name: I18n.t("user.like_notification_frequency.first_time_and_daily"),
        value: 1
      },
      { name: I18n.t("user.like_notification_frequency.first_time"), value: 2 },
      { name: I18n.t("user.like_notification_frequency.never"), value: 3 }
    ];

    this.autoTrackDurations = [
      { name: I18n.t("user.auto_track_options.never"), value: -1 },
      { name: I18n.t("user.auto_track_options.immediately"), value: 0 },
      {
        name: I18n.t("user.auto_track_options.after_30_seconds"),
        value: 30000
      },
      { name: I18n.t("user.auto_track_options.after_1_minute"), value: 60000 },
      {
        name: I18n.t("user.auto_track_options.after_2_minutes"),
        value: 120000
      },
      {
        name: I18n.t("user.auto_track_options.after_3_minutes"),
        value: 180000
      },
      {
        name: I18n.t("user.auto_track_options.after_4_minutes"),
        value: 240000
      },
      {
        name: I18n.t("user.auto_track_options.after_5_minutes"),
        value: 300000
      },
      {
        name: I18n.t("user.auto_track_options.after_10_minutes"),
        value: 600000
      }
    ];

    this.notificationLevelsForReplying = [
      {
        name: I18n.t("topic.notifications.watching.title"),
        value: NotificationLevels.WATCHING
      },
      {
        name: I18n.t("topic.notifications.tracking.title"),
        value: NotificationLevels.TRACKING
      },
      {
        name: I18n.t("topic.notifications.regular.title"),
        value: NotificationLevels.REGULAR
      }
    ];

    this.considerNewTopicOptions = [
      { name: I18n.t("user.new_topic_duration.not_viewed"), value: -1 },
      { name: I18n.t("user.new_topic_duration.after_1_day"), value: 60 * 24 },
      { name: I18n.t("user.new_topic_duration.after_2_days"), value: 60 * 48 },
      {
        name: I18n.t("user.new_topic_duration.after_1_week"),
        value: 7 * 60 * 24
      },
      {
        name: I18n.t("user.new_topic_duration.after_2_weeks"),
        value: 2 * 7 * 60 * 24
      },
      { name: I18n.t("user.new_topic_duration.last_here"), value: -2 }
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
    }
  }
});
