import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { fn, hash } from "@ember/helper";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { isEmpty } from "@ember/utils";
import ItsATrap from "@discourse/itsatrap";
import DSelect from "discourse/components/d-select";
import {
  BUMP_TYPE,
  CLOSE_AFTER_LAST_POST_STATUS_TYPE,
  CLOSE_STATUS_TYPE,
  DELETE_REPLIES_TYPE,
  DELETE_STATUS_TYPE,
  OPEN_STATUS_TYPE,
  PUBLISH_TO_CATEGORY_STATUS_TYPE,
} from "discourse/components/modal/edit-topic-timer";
import RelativeTimePicker from "discourse/components/relative-time-picker";
import TimeShortcutPicker from "discourse/components/time-shortcut-picker";
import TopicTimerInfo from "discourse/components/topic-timer-info";
import icon from "discourse/helpers/d-icon";
import KeyboardShortcuts from "discourse/lib/keyboard-shortcuts";
import {
  TIME_SHORTCUT_TYPES,
  timeShortcuts,
} from "discourse/lib/time-shortcut";
import { i18n } from "discourse-i18n";
import CategoryChooser from "select-kit/components/category-chooser";
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

  <template>
    <form>
      <div class="control-group">
        <DSelect
          @value={{this.statusType}}
          class="timer-type"
          @onChange={{@onChangeStatusType}}
          as |select|
        >
          {{#each @timerTypes as |timer|}}
            <select.Option @value={{timer.id}}>{{timer.name}}</select.Option>
          {{/each}}
        </DSelect>
      </div>

      {{#if this.publishToCategory}}
        <div class="control-group">
          <label class="control-label">
            {{i18n "topic.topic_status_update.publish_to"}}
          </label>
          <CategoryChooser
            @value={{@topicTimer.category_id}}
            @onChange={{fn (mut @topicTimer.category_id)}}
            @options={{hash excludeCategoryId=this.excludeCategoryId}}
          />
        </div>
      {{/if}}

      {{#if this.showFutureDateInput}}
        <label class="control-label">
          {{i18n "topic.topic_status_update.when"}}
        </label>
        <TimeShortcutPicker
          @timeShortcuts={{this.timeOptions}}
          @prefilledDatetime={{@topicTimer.execute_at}}
          @onTimeSelected={{this.onTimeSelected}}
          @hiddenOptions={{this.hiddenTimeShortcutOptions}}
          @_itsatrap={{this._itsatrap}}
        />
      {{/if}}

      {{#if this.useDuration}}
        <div class="controls">
          <label class="control-label">
            {{i18n "topic.topic_status_update.duration"}}
          </label>
          <RelativeTimePicker
            @onChange={{this.changeDuration}}
            @durationMinutes={{@topicTimer.duration_minutes}}
          />
        </div>
      {{/if}}

      {{#if this.willCloseImmediately}}
        <div class="warning">
          {{icon "triangle-exclamation"}}
          {{this.willCloseI18n}}
        </div>
      {{/if}}

      {{#if this.showTopicTimerInfo}}
        <div class="alert alert-info modal-topic-timer-info">
          <TopicTimerInfo
            @statusType={{this.statusType}}
            @executeAt={{this.executeAt}}
            @basedOnLastPost={{@topicTimer.based_on_last_post}}
            @durationMinutes={{@topicTimer.duration_minutes}}
            @categoryId={{@topicTimer.category_id}}
          />
        </div>
      {{/if}}
    </form>
  </template>
}
