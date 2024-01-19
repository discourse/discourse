import Mixin from "@ember/object/mixin";
import DiscourseURL from "discourse/lib/url";
import deprecated from "discourse-common/lib/deprecated";
import discourseComputed from "discourse-common/utils/decorators";

export default Mixin.create({
  queryParams: ["period"],
  period: "monthly",

  init() {
    this._super(...arguments);

    deprecated(
      "PeriodComputation mixin is deprecated. Use AdminDashboardTabController instead.",
      {
        id: "discourse.period-mixin",
        since: "3.2.0.beta5-dev",
      }
    );
    this.availablePeriods = ["yearly", "quarterly", "monthly", "weekly"];
  },

  @discourseComputed("period")
  startDate: {
    get(period) {
      const fullDay = moment().locale("en").utc().endOf("day");

      switch (period) {
        case "yearly":
          return fullDay.subtract(1, "year").startOf("day");
        case "quarterly":
          return fullDay.subtract(3, "month").startOf("day");
        case "weekly":
          return fullDay.subtract(6, "days").startOf("day");
        case "monthly":
          return fullDay.subtract(1, "month").startOf("day");
        default:
          return fullDay.subtract(1, "month").startOf("day");
      }
    },

    set(period) {
      return period;
    },
  },

  @discourseComputed()
  lastWeek() {
    return moment().locale("en").utc().endOf("day").subtract(1, "week");
  },

  @discourseComputed()
  lastMonth() {
    return moment().locale("en").utc().startOf("day").subtract(1, "month");
  },

  @discourseComputed()
  endDate: {
    get() {
      return moment().locale("en").utc().endOf("day");
    },

    set(endDate) {
      return endDate;
    },
  },

  @discourseComputed()
  today() {
    return moment().locale("en").utc().endOf("day");
  },

  actions: {
    changePeriod(period) {
      DiscourseURL.routeTo(this._reportsForPeriodURL(period));
    },
  },
});
