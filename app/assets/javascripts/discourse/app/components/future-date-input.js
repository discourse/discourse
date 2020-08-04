import I18n from "I18n";
import { isEmpty } from "@ember/utils";
import { equal, and, empty, or } from "@ember/object/computed";
import Component from "@ember/component";
import discourseComputed, { observes } from "discourse-common/utils/decorators";
import { FORMAT } from "select-kit/components/future-date-input-selector";
import { PUBLISH_TO_CATEGORY_STATUS_TYPE } from "discourse/controllers/edit-topic-timer";

export default Component.extend({
  selection: null,
  date: null,
  time: null,
  includeDateTime: true,
  duration: null,
  durationType: "hours",
  isCustom: equal("selection", "pick_date_and_time"),
  isBasedOnLastPost: equal("selection", "set_based_on_last_post"),
  displayDateAndTimePicker: and("includeDateTime", "isCustom"),
  displayLabel: null,
  displayNumberInput: or("isBasedOnLastPost", "isBasedOnDuration"),

  init() {
    this._super(...arguments);

    if (this.input) {
      if (this.basedOnLastPost) {
        this.set("selection", "set_based_on_last_post");
      } else if (this.isBasedOnDuration) {
        this.set("selection", null);
      } else {
        const datetime = moment(this.input);
        this.setProperties({
          selection: "pick_date_and_time",
          date: datetime.format("YYYY-MM-DD"),
          time: datetime.format("HH:mm")
        });
        this._updateInput();
      }
    }
  },

  timeInputDisabled: empty("date"),

  @observes("date", "time")
  _updateInput() {
    if (!this.date) {
      this.set("time", null);
    }

    const time = this.time ? ` ${this.time}` : "";
    const dateTime = moment(`${this.date}${time}`);

    if (dateTime.isValid()) {
      this.attrs.onChangeInput &&
        this.attrs.onChangeInput(dateTime.format(FORMAT));
    } else {
      this.attrs.onChangeInput && this.attrs.onChangeInput(null);
    }
  },

  @observes("isBasedOnLastPost")
  _updateBasedOnLastPost() {
    this.set("basedOnLastPost", this.isBasedOnLastPost);
  },

  @observes("duration")
  _updateDuration() {
    this.attrs.onChangeDuration &&
      this.attrs.onChangeDuration(parseInt(this.duration, 0));
  },

  @discourseComputed(
    "input",
    "duration",
    "isBasedOnLastPost",
    "isBasedOnDuration",
    "durationType"
  )
  executeAt(
    input,
    duration,
    isBasedOnLastPost,
    isBasedOnDuration,
    durationType
  ) {
    if (isBasedOnLastPost || isBasedOnDuration) {
      return moment(input)
        .add(parseInt(duration, 0), durationType)
        .format(FORMAT);
    } else {
      return input;
    }
  },

  @discourseComputed("durationType")
  durationLabel(durationType) {
    return I18n.t(
      `topic.topic_status_update.num_of_${
        durationType === "hours" ? "hours" : "days"
      }`
    );
  },

  didReceiveAttrs() {
    this._super(...arguments);

    if (this.label) this.set("displayLabel", I18n.t(this.label));
  },

  @discourseComputed(
    "statusType",
    "input",
    "isCustom",
    "date",
    "time",
    "willCloseImmediately",
    "categoryId",
    "displayNumberInput",
    "duration"
  )
  showTopicStatusInfo(
    statusType,
    input,
    isCustom,
    date,
    time,
    willCloseImmediately,
    categoryId,
    displayNumberInput,
    duration
  ) {
    if (!statusType || willCloseImmediately) return false;

    if (statusType === PUBLISH_TO_CATEGORY_STATUS_TYPE && isEmpty(categoryId)) {
      return false;
    }

    if (isCustom) {
      if (date) {
        return moment(`${date}${time ? " " + time : ""}`).isAfter(moment());
      }
      return time;
    } else if (displayNumberInput) {
      return duration;
    } else {
      return input;
    }
  },

  @discourseComputed("isBasedOnLastPost", "input", "lastPostedAt")
  willCloseImmediately(isBasedOnLastPost, input, lastPostedAt) {
    if (isBasedOnLastPost && input) {
      let closeDate = moment(lastPostedAt);
      closeDate = closeDate.add(input, "hours");
      return closeDate < moment();
    }
  },

  @discourseComputed("isBasedOnLastPost", "lastPostedAt")
  willCloseI18n(isBasedOnLastPost, lastPostedAt) {
    if (isBasedOnLastPost) {
      const diff = Math.round(
        (new Date() - new Date(lastPostedAt)) / (1000 * 60 * 60)
      );
      return I18n.t("topic.auto_close_immediate", { count: diff });
    }
  }
});
