import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { hash } from "@ember/helper";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { htmlSafe } from "@ember/template";
import { isEmpty } from "@ember/utils";
import { NotificationLevels } from "discourse/lib/notification-levels";
import i18n from "discourse-common/helpers/i18n";
import getURL from "discourse-common/lib/get-url";
import I18n from "discourse-i18n";
import TopicNotificationsOptions from "select-kit/components/topic-notifications-options";

export default class TopicNotificationsButton extends Component {
  @service currentUser;

  @tracked isLoading = false;

  get notificationLevel() {
    return this.args.topic.get("details.notification_level");
  }

  get appendReason() {
    return this.args.appendReason ?? true;
  }

  get showFullTitle() {
    return this.args.showFullTitle ?? true;
  }

  get showCaret() {
    return this.args.showCaret ?? true;
  }

  get reasonText() {
    const topic = this.args.topic;
    const level = topic.get("details.notification_level") ?? 1;
    const reason = topic.get("details.notifications_reason_id");
    let localeString = `topic.notifications.reasons.${level}`;

    if (typeof reason === "number") {
      let localeStringWithReason = `${localeString}_${reason}`;

      if (this._reasonStale(level, reason)) {
        localeStringWithReason += "_stale";
      }

      // some sane protection for missing translations of edge cases
      if (I18n.lookup(localeStringWithReason, { locale: "en" })) {
        localeString = localeStringWithReason;
      }
    }

    if (
      this.currentUser?.user_option.mailing_list_mode &&
      level > NotificationLevels.MUTED
    ) {
      return I18n.t("topic.notifications.reasons.mailing_list_mode");
    } else {
      return I18n.t(localeString, {
        username: this.currentUser?.username_lower,
        basePath: getURL(""),
      });
    }
  }

  // The user may have changed their category or tag tracking settings
  // since this topic was tracked/watched based on those settings in the
  // past. In that case we need to alter the reason message we show them
  // otherwise it is very confusing for the end user to be told they are
  // tracking a topic because of a category, when they are no longer tracking
  // that category.
  _reasonStale(level, reason) {
    if (!this.currentUser) {
      return;
    }

    const watchedCategoryIds = this.currentUser.watched_category_ids || [];
    const trackedCategoryIds = this.currentUser.tracked_category_ids || [];
    const watchedTags = this.currentUser.watched_tags || [];

    if (this.args.topic.category_id) {
      if (level === 2 && reason === 8) {
        // 2_8 tracking category
        return !trackedCategoryIds.includes(this.args.topic.category_id);
      } else if (level === 3 && reason === 6) {
        // 3_6 watching category
        return !watchedCategoryIds.includes(this.args.topic.category_id);
      }
    } else if (!isEmpty(this.args.topic.tags)) {
      if (level === 3 && reason === 10) {
        // 3_10 watching tag
        return !this.args.topic.tags.some((tag) => watchedTags.includes(tag));
      }
    }

    return false;
  }

  @action
  async changeTopicNotificationLevel(levelId) {
    if (levelId === this.notificationLevel) {
      return;
    }

    this.isLoading = true;

    try {
      await this.args.topic.details.updateNotifications(levelId);
    } finally {
      this.isLoading = false;
    }
  }

  <template>
    <div class="topic-notifications-button">
      {{#if this.appendReason}}
        <p class="reason">
          <TopicNotificationsOptions
            @value={{this.notificationLevel}}
            @topic={{@topic}}
            @onChange={{this.changeTopicNotificationLevel}}
            @options={{hash
              icon=(if this.isLoading "spinner")
              showFullTitle=this.showFullTitle
              showCaret=this.showCaret
              headerAriaLabel=(i18n "topic.notifications.title")
            }}
          />
          <span class="text">{{htmlSafe this.reasonText}}</span>
        </p>
      {{else}}
        <TopicNotificationsOptions
          @value={{this.notificationLevel}}
          @topic={{@topic}}
          @onChange={{this.changeTopicNotificationLevel}}
          @options={{hash
            icon=(if this.isLoading "spinner")
            showFullTitle=this.showFullTitle
            showCaret=this.showCaret
            headerAriaLabel=(i18n "topic.notifications.title")
          }}
        />
      {{/if}}
    </div>
  </template>
}
