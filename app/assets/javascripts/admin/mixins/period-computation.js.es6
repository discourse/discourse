import DiscourseURL from "discourse/lib/url";
import computed from "ember-addons/ember-computed-decorators";
import Mixin from "@ember/object/mixin";

export default Mixin.create({
  queryParams: ["period"],
  period: "monthly",

  init() {
    this._super(...arguments);

    this.availablePeriods = ["yearly", "quarterly", "monthly", "weekly"];
  },

  @computed("period")
  startDate(period) {
    let fullDay = moment()
      .locale("en")
      .utc()
      .subtract(1, "day");

    switch (period) {
      case "yearly":
        return fullDay.subtract(1, "year").startOf("day");
        break;
      case "quarterly":
        return fullDay.subtract(3, "month").startOf("day");
        break;
      case "weekly":
        return fullDay.subtract(1, "week").startOf("day");
        break;
      case "monthly":
        return fullDay.subtract(1, "month").startOf("day");
        break;
      default:
        return fullDay.subtract(1, "month").startOf("day");
    }
  },

  @computed()
  lastWeek() {
    return moment()
      .locale("en")
      .utc()
      .endOf("day")
      .subtract(1, "week");
  },

  @computed()
  lastMonth() {
    return moment()
      .locale("en")
      .utc()
      .startOf("day")
      .subtract(1, "month");
  },

  @computed()
  endDate() {
    return moment()
      .locale("en")
      .utc()
      .subtract(1, "day")
      .endOf("day");
  },

  @computed()
  today() {
    return moment()
      .locale("en")
      .utc()
      .endOf("day");
  },

  actions: {
    changePeriod(period) {
      DiscourseURL.routeTo(this._reportsForPeriodURL(period));
    }
  }
});
