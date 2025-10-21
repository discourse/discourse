import Controller from "@ember/controller";
import { action } from "@ember/object";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { i18n } from "discourse-i18n";

export default class NotificationsController extends Controller {
  subpageTitle = i18n("user.preferences_nav.notifications");

  init() {
    super.init(...arguments);

    this.saveAttrNames = [
      "allow_private_messages",
      "auto_track_topics_after_msecs",
      "enable_allowed_pm_users",
      "like_notification_frequency",
      "muted_usernames",
      "new_topic_duration_minutes",
      "notification_level_when_replying",
      "notify_on_linked_posts",
      "user_notification_schedule",
    ];

    this.likeNotificationFrequencies = [
      { name: i18n("user.like_notification_frequency.always"), value: 0 },
      {
        name: i18n("user.like_notification_frequency.first_time_and_daily"),
        value: 1,
      },
      { name: i18n("user.like_notification_frequency.first_time"), value: 2 },
      { name: i18n("user.like_notification_frequency.never"), value: 3 },
    ];
  }

  @action
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
