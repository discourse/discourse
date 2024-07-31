import { computed } from "@ember/object";
import Mixin from "@ember/object/mixin";
import DiscourseURL from "discourse/lib/url";
import deprecated from "discourse-common/lib/deprecated";

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

  startDate: computed("period", {
    get() {
      const period = this.period;
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
  }),

  get lastWeek() {
    return moment().locale("en").utc().endOf("day").subtract(1, "week");
  },

  get lastMonth() {
    return moment().locale("en").utc().startOf("day").subtract(1, "month");
  },

  get endDate() {
    return moment().locale("en").utc().endOf("day");
  },
  set endDate(value) {
    /* noop */
  },

  get today() {
    return moment().locale("en").utc().endOf("day");
  },

  actions: {
    changePeriod(period) {
      DiscourseURL.routeTo(this._reportsForPeriodURL(period));
    },
  },
});
