import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { isEmpty } from "@ember/utils";
import ItsATrap from "@discourse/itsatrap";
import {
  BUMP_TYPE,
  CLOSE_AFTER_LAST_POST_STATUS_TYPE,
  CLOSE_STATUS_TYPE,
  DELETE_REPLIES_TYPE,
  DELETE_STATUS_TYPE,
  OPEN_STATUS_TYPE,
  PUBLISH_TO_CATEGORY_STATUS_TYPE,
} from "discourse/components/modal/edit-topic-timer";
import KeyboardShortcuts from "discourse/lib/keyboard-shortcuts";
import {
  TIME_SHORTCUT_TYPES,
  timeShortcuts,
} from "discourse/lib/time-shortcut";
import { i18n } from "discourse-i18n";
import { FORMAT } from "select-kit/components/future-date-input-selector";

export default class EditTopicTimerForm extends Component {
  @service currentUser;

  @tracked timerType;

  constructor() {
    super(...arguments);

    KeyboardShortcuts.pause();
    this._itsatrap = new ItsATrap();
  }

  willDestroy() {
    super.willDestroy(...arguments);

    this._itsatrap.destroy();
    KeyboardShortcuts.unpause();
  }

  get showTimeOnly() {
    return (
      this.statusType === OPEN_STATUS_TYPE ||
      this.statusType === DELETE_STATUS_TYPE ||
      this.statusType === BUMP_TYPE
    );
  }

  get showFutureDateInput() {
    return (
      this.showTimeOnly ||
      this.publishToCategory ||
      this.statusType === CLOSE_STATUS_TYPE
    );
  }

  get useDuration() {
    return this.autoCloseAfterLastPost || this.autoDeleteReplies;
  }

  get autoCloseAfterLastPost() {
    return this.statusType === CLOSE_AFTER_LAST_POST_STATUS_TYPE;
  }

  get publishToCategory() {
    return this.statusType === PUBLISH_TO_CATEGORY_STATUS_TYPE;
  }

  get autoDeleteReplies() {
    return this.statusType === DELETE_REPLIES_TYPE;
  }

  get statusType() {
    return this.args.topicTimer.status_type;
  }

  get excludeCategoryId() {
    if (this.args.topic.visible) {
      return this.args.topic.category_id;
    }
  }

  get timeOptions() {
    const timezone = this.currentUser.user_option.timezone;
    const shortcuts = timeShortcuts(timezone);

    return [
      shortcuts.laterToday(),
      shortcuts.tomorrow(),
      shortcuts.laterThisWeek(),
      shortcuts.thisWeekend(),
      shortcuts.monday(),
      shortcuts.twoWeeks(),
      shortcuts.nextMonth(),
      shortcuts.sixMonths(),
    ];
  }

  get hiddenTimeShortcutOptions() {
    return [
      TIME_SHORTCUT_TYPES.NONE,
      TIME_SHORTCUT_TYPES.LATER_TODAY,
      TIME_SHORTCUT_TYPES.LATER_THIS_WEEK,
    ];
  }

  get executeAt() {
    if (this.useDuration) {
      return moment()
        .add(parseFloat(this.args.topicTimer.duration_minutes), "minutes")
        .format(FORMAT);
    } else {
      return this.args.topicTimer.updateTime;
    }
  }

  get willCloseImmediately() {
    if (this.autoCloseAfterLastPost && this.args.topicTimer.duration_minutes) {
      const closeDate = moment(this.args.topic.last_posted_at).add(
        this.args.topicTimer.duration_minutes,
        "minutes"
      );
      return closeDate < moment();
    }
  }

  get willCloseI18n() {
    if (this.autoCloseAfterLastPost) {
      const diff = Math.round(
        (new Date() - new Date(this.args.topic.last_posted_at)) /
          (1000 * 60 * 60)
      );
      return i18n("topic.auto_close_momentarily", { count: diff });
    }
  }

  get durationLabel() {
    return i18n(
      `topic.topic_status_update.num_of_${
        this.autoDeleteReplies ? "days" : "hours"
      }`
    );
  }

  get showTopicTimerInfo() {
    if (!this.statusType || this.willCloseImmediately) {
      return false;
    }

    if (
      this.statusType === PUBLISH_TO_CATEGORY_STATUS_TYPE &&
      isEmpty(this.args.topicTimer.category_id)
    ) {
      return false;
    }

    if (this.timerType === "custom" && this.args.topicTimer.updateTime) {
      if (moment(this.args.topicTimer.updateTime) < moment()) {
        return false;
      }
    } else if (this.useDuration) {
      return this.args.topicTimer.duration_minutes;
    }

    return this.args.topicTimer.updateTime;
  }

  @action
  onTimeSelected(type, time) {
    this.timerType = type;
    this.args.onChangeInput(type, time);
  }

  @action
  changeDuration(newDurationMins) {
    this.args.topicTimer.duration_minutes = newDurationMins;
  }
}
