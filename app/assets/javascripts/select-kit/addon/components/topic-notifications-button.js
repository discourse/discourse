import { action, computed } from "@ember/object";
import I18n from "I18n";
import { isEmpty } from "@ember/utils";
import { NotificationLevels } from "discourse/lib/notification-levels";
import discourseComputed from "discourse-common/utils/decorators";
import getURL from "discourse-common/lib/get-url";
import Component from "@ember/component";
import layout from "select-kit/templates/components/topic-notifications-button";

export default Component.extend({
  layout,
  classNames: ["topic-notifications-button"],
  classNameBindings: ["isLoading"],
  appendReason: true,
  showFullTitle: true,
  notificationLevel: null,
  topic: null,
  showCaret: true,
  isLoading: false,
  icon: computed("isLoading", function () {
    return this.isLoading ? "spinner" : null;
  }),

  @action
  changeTopicNotificationLevel(levelId) {
    if (levelId !== this.notificationLevel) {
      this.set("isLoading", true);
      this.topic.details
        .updateNotifications(levelId)
        .finally(() => this.set("isLoading", false));
    }
  },

  @discourseComputed(
    "topic",
    "topic.details.{notification_level,notifications_reason_id}"
  )
  notificationReasonText(topic, topicDetails) {
    let level = topicDetails.notification_level;
    let reason = topicDetails.notifications_reason_id;

    if (typeof level !== "number") {
      level = 1;
    }

    let localeString = `topic.notifications.reasons.${level}`;
    if (typeof reason === "number") {
      let localeStringWithReason = localeString + "_" + reason;

      if (
        this._notificationReasonStale(level, reason, topic, this.currentUser)
      ) {
        localeStringWithReason += "_stale";
      }

      // some sane protection for missing translations of edge cases
      if (I18n.lookup(localeStringWithReason, { locale: "en" })) {
        localeString = localeStringWithReason;
      }
    }

    if (
      this.currentUser &&
      this.currentUser.user_option.mailing_list_mode &&
      level > NotificationLevels.MUTED
    ) {
      return I18n.t("topic.notifications.reasons.mailing_list_mode");
    } else {
      return I18n.t(localeString, {
        username: this.currentUser && this.currentUser.username_lower,
        basePath: getURL(""),
      });
    }
  },

  // The user may have changed their category or tag tracking settings
  // since this topic was tracked/watched based on those settings in the
  // past. In that case we need to alter the reason message we show them
  // otherwise it is very confusing for the end user to be told they are
  // tracking a topic because of a category, when they are no longer tracking
  // that category.
  _notificationReasonStale(level, reason, topic, currentUser) {
    if (!currentUser) {
      return;
    }

    let categoryId = topic.category_id;
    let tags = topic.tags;
    let watchedCategoryIds = currentUser.watched_category_ids || [];
    let trackedCategoryIds = currentUser.tracked_category_ids || [];
    let watchedTags = currentUser.watched_tags || [];

    // 2_8 tracking category
    if (categoryId) {
      if (level === 2 && reason === 8) {
        if (!trackedCategoryIds.includes(categoryId)) {
          return true;
        }

        // 3_6 watching category
      } else if (level === 3 && reason === 6) {
        if (!watchedCategoryIds.includes(categoryId)) {
          return true;
        }
      }
    } else if (!isEmpty(tags)) {
      // 3_10 watching tag
      if (level === 3 && reason === 10) {
        if (!tags.some((tag) => watchedTags.includes(tag))) {
          return true;
        }
      }
    }

    return false;
  },
});
