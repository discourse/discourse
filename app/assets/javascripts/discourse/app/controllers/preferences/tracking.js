import Controller from "@ember/controller";
import { NotificationLevels } from "discourse/lib/notification-levels";
import I18n from "I18n";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { action, computed } from "@ember/object";
import { inject as service } from "@ember/service";
import { tracked } from "@glimmer/tracking";

export default class extends Controller {
  @service currentUser;
  @service siteSettings;
  @tracked saved = false;

  likeNotificationFrequencies = [
    { name: I18n.t("user.like_notification_frequency.always"), value: 0 },
    {
      name: I18n.t("user.like_notification_frequency.first_time_and_daily"),
      value: 1,
    },
    { name: I18n.t("user.like_notification_frequency.first_time"), value: 2 },
    { name: I18n.t("user.like_notification_frequency.never"), value: 3 },
  ];

  autoTrackDurations = [
    { name: I18n.t("user.auto_track_options.never"), value: -1 },
    { name: I18n.t("user.auto_track_options.immediately"), value: 0 },
    {
      name: I18n.t("user.auto_track_options.after_30_seconds"),
      value: 30000,
    },
    { name: I18n.t("user.auto_track_options.after_1_minute"), value: 60000 },
    {
      name: I18n.t("user.auto_track_options.after_2_minutes"),
      value: 120000,
    },
    {
      name: I18n.t("user.auto_track_options.after_3_minutes"),
      value: 180000,
    },
    {
      name: I18n.t("user.auto_track_options.after_4_minutes"),
      value: 240000,
    },
    {
      name: I18n.t("user.auto_track_options.after_5_minutes"),
      value: 300000,
    },
    {
      name: I18n.t("user.auto_track_options.after_10_minutes"),
      value: 600000,
    },
  ];

  notificationLevelsForReplying = [
    {
      name: I18n.t("topic.notifications.watching.title"),
      value: NotificationLevels.WATCHING,
    },
    {
      name: I18n.t("topic.notifications.tracking.title"),
      value: NotificationLevels.TRACKING,
    },
    {
      name: I18n.t("topic.notifications.regular.title"),
      value: NotificationLevels.REGULAR,
    },
  ];

  considerNewTopicOptions = [
    { name: I18n.t("user.new_topic_duration.not_viewed"), value: -1 },
    { name: I18n.t("user.new_topic_duration.after_1_day"), value: 60 * 24 },
    { name: I18n.t("user.new_topic_duration.after_2_days"), value: 60 * 48 },
    {
      name: I18n.t("user.new_topic_duration.after_1_week"),
      value: 7 * 60 * 24,
    },
    {
      name: I18n.t("user.new_topic_duration.after_2_weeks"),
      value: 2 * 7 * 60 * 24,
    },
    { name: I18n.t("user.new_topic_duration.last_here"), value: -2 },
  ];

  get canSee() {
    return this.currentUser.id === this.model.id;
  }

  @computed(
    "model.watched_tags.[]",
    "model.watching_first_post_tags.[]",
    "model.tracked_tags.[]",
    "model.muted_tags.[]"
  )
  get selectedTags() {
    return []
      .concat(
        this.model.watched_tags,
        this.model.watching_first_post_tags,
        this.model.tracked_tags,
        this.model.muted_tags
      )
      .filter((t) => t);
  }

  @computed(
    "model.watchedCategories",
    "model.watchedFirstPostCategories",
    "model.trackedCategories",
    "model.mutedCategories",
    "model.regularCategories",
    "siteSettings.mute_all_categories_by_default"
  )
  get selectedCategories() {
    return []
      .concat(
        this.model.watchedCategories,
        this.model.watchedFirstPostCategories,
        this.model.trackedCategories,
        this.siteSettings.mute_all_categories_by_default
          ? this.model.regularCategories
          : this.model.mutedCategories
      )
      .filter((t) => t);
  }

  @computed("siteSettings.remove_muted_tags_from_latest")
  get hideMutedTags() {
    return this.siteSettings.remove_muted_tags_from_latest !== "never";
  }

  get canSave() {
    return this.canSee || this.currentUser.admin;
  }

  @computed(
    "siteSettings.tagging_enabled",
    "siteSettings.mute_all_categories_by_default"
  )
  get saveAttrNames() {
    const attrs = [
      "new_topic_duration_minutes",
      "auto_track_topics_after_msecs",
      "notification_level_when_replying",
      this.siteSettings.mute_all_categories_by_default
        ? "regular_category_ids"
        : "muted_category_ids",
      "watched_category_ids",
      "tracked_category_ids",
      "watched_first_post_category_ids",
    ];

    if (this.siteSettings.tagging_enabled) {
      attrs.push(
        "muted_tags",
        "tracked_tags",
        "watched_tags",
        "watching_first_post_tags"
      );
    }

    return attrs;
  }

  @action
  save() {
    this.saved = false;

    return this.model
      .save(this.saveAttrNames)
      .then(() => {
        this.saved = true;
      })
      .catch(popupAjaxError);
  }
}
