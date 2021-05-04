import EmberObject from "@ember/object";
import { isEmpty } from "@ember/utils";
import I18n from "I18n";
import { NotificationLevels } from "discourse/lib/notification-levels";
import RestModel from "discourse/models/rest";
import User from "discourse/models/user";
import { ajax } from "discourse/lib/ajax";

/**
  A model representing a Topic's details that aren't always present, such as a list of participants.
  When showing topics in lists and such this information should not be required.
**/
import discourseComputed from "discourse-common/utils/decorators";
import getURL from "discourse-common/lib/get-url";

const TopicDetails = RestModel.extend({
  loaded: false,

  updateFromJson(details) {
    const topic = this.topic;

    if (details.allowed_users) {
      details.allowed_users = details.allowed_users.map(function (u) {
        return User.create(u);
      });
    }

    if (details.participants) {
      details.participants = details.participants.map(function (p) {
        p.topic = topic;
        return EmberObject.create(p);
      });
    }

    this.setProperties(details);
    this.set("loaded", true);
  },

  @discourseComputed("notification_level", "notifications_reason_id", "topic")
  notificationReasonText(level, reason, topic) {
    if (typeof level !== "number") {
      level = 1;
    }

    let localeString = `topic.notifications.reasons.${level}`;
    if (typeof reason === "number") {
      let localeStringWithReason = localeString + "_" + reason;

      if (this._notificationReasonStale(level, reason, User.current(), topic)) {
        localeStringWithReason += "_stale";
      }

      // some sane protection for missing translations of edge cases
      if (I18n.lookup(localeStringWithReason, { locale: "en" })) {
        localeString = localeStringWithReason;
      }
    }

    if (
      User.currentProp("mailing_list_mode") &&
      level > NotificationLevels.MUTED
    ) {
      return I18n.t("topic.notifications.reasons.mailing_list_mode");
    } else {
      return I18n.t(localeString, {
        username: User.currentProp("username_lower"),
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
  _notificationReasonStale(level, reason, currentUser, topic) {
    if (!currentUser) {
      return;
    }

    let categoryId = topic.category_id;
    let tags = topic.tags;

    // 2_8 tracking category
    if (categoryId) {
      if (level === 2 && reason === 8) {
        if (!currentUser.tracked_category_ids.includes(categoryId)) {
          return true;
        }

        // 3_6 watching category
      } else if (level === 3 && reason === 6) {
        if (!currentUser.watched_category_ids.includes(categoryId)) {
          return true;
        }
      }
    } else if (!isEmpty(tags)) {
      // 3_10 watching tag
      if (level === 3 && reason === 10) {
        if (!tags.some((tag) => currentUser.watched_tags.includes(tag))) {
          return true;
        }
      }
    }

    return false;
  },

  updateNotifications(level) {
    return ajax(`/t/${this.get("topic.id")}/notifications`, {
      type: "POST",
      data: { notification_level: level },
    }).then(() => {
      this.setProperties({
        notification_level: level,
        notifications_reason_id: null,
      });
    });
  },

  removeAllowedGroup(group) {
    const groups = this.allowed_groups;
    const name = group.name;

    return ajax("/t/" + this.get("topic.id") + "/remove-allowed-group", {
      type: "PUT",
      data: { name: name },
    }).then(() => {
      groups.removeObject(groups.findBy("name", name));
    });
  },

  removeAllowedUser(user) {
    const users = this.allowed_users;
    const username = user.get("username");

    return ajax("/t/" + this.get("topic.id") + "/remove-allowed-user", {
      type: "PUT",
      data: { username: username },
    }).then(() => {
      users.removeObject(users.findBy("username", username));
    });
  },
});

export default TopicDetails;
