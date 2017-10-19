import { default as computed, observes } from "ember-addons/ember-computed-decorators";
import ComboBoxComponent from "select-box-kit/components/combo-box";
import { CLOSE_STATUS_TYPE } from "discourse/controllers/edit-topic-timer";
import DatetimeMixin from "select-box-kit/components/future-date-input-selector/mixin";

export const LATER_TODAY = "later_today";
export const TOMORROW = "tomorrow";
export const LATER_THIS_WEEK = "later_this_week";
export const THIS_WEEKEND = "this_weekend";
export const NEXT_WEEK = "next_week";
export const TWO_WEEKS = "two_weeks";
export const NEXT_MONTH = "next_month";
export const FOREVER = "forever";

export const PICK_DATE_AND_TIME = "pick_date_and_time";
export const SET_BASED_ON_LAST_POST = "set_based_on_last_post";

export const FORMAT = "YYYY-MM-DD HH:mm";

export default ComboBoxComponent.extend(DatetimeMixin, {
  classNames: ["future-date-input-selector"],
  isCustom: Ember.computed.equal("value", PICK_DATE_AND_TIME),
  clearable: true,
  rowComponent: "future-date-input-selector/future-date-input-selector-row",
  headerComponent: "future-date-input-selector/future-date-input-selector-header",

  @computed
  content() {
    const selections = [];
    const now = moment();
    const canScheduleToday = (24 - now.hour()) > 6;
    const day = now.day();

    if (canScheduleToday) {
      selections.push({
        id: LATER_TODAY,
        name: I18n.t("topic.auto_update_input.later_today")
      });
    }

    selections.push({
      id: TOMORROW,
      name: I18n.t("topic.auto_update_input.tomorrow")
    });

    if (!canScheduleToday && day < 4) {
      selections.push({
        id: LATER_THIS_WEEK,
        name: I18n.t("topic.auto_update_input.later_this_week")
      });
    }

    if (day < 5 && this.get("includeWeekend")) {
      selections.push({
        id: THIS_WEEKEND,
        name: I18n.t("topic.auto_update_input.this_weekend")
      });
    }

    if (day !== 7)  {
      selections.push({
        id: NEXT_WEEK,
        name: I18n.t("topic.auto_update_input.next_week")
      });
    }

    selections.push({
      id: TWO_WEEKS,
      name: I18n.t("topic.auto_update_input.two_weeks")
    });

    if (moment().endOf("month").date() !== now.date()) {
      selections.push({
        id: NEXT_MONTH,
        name: I18n.t("topic.auto_update_input.next_month")
      });
    }

    if (this.get("includeForever")) {
      selections.push({
        id: FOREVER,
        name: I18n.t("topic.auto_update_input.forever")
      });
    }

    selections.push({
      id: PICK_DATE_AND_TIME,
      name: I18n.t("topic.auto_update_input.pick_date_and_time")
    });

    if (this.get("statusType") === CLOSE_STATUS_TYPE) {
      selections.push({
        id: SET_BASED_ON_LAST_POST,
        name: I18n.t("topic.auto_update_input.set_based_on_last_post")
      });
    }

    return selections;
  },

  @observes("value")
  _updateInput() {
    if (this.get("isCustom")) return;
    let input = null;
    const { time } = this.get("updateAt");

    if (time && !Ember.isEmpty(this.get("value"))) {
      input = time.format(FORMAT);
    }

    this.set("input", input);
  },

  @computed("value")
  updateAt(value) {
    return this._updateAt(value);
  }
});
