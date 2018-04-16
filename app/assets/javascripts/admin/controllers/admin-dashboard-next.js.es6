import DiscourseURL from 'discourse/lib/url';
import computed from 'ember-addons/ember-computed-decorators';

export default Ember.Controller.extend({
  queryParams: ["period"],

  period: "all",

  @computed("period")
  startDate(period) {
    if (period === "all") return null;

    switch (period) {
      case "yearly":
        return moment().subtract(1, "year").startOf("day");
        break;
      case "quarterly":
        return moment().subtract(3, "month").startOf("day");
        break;
      case "weekly":
        return moment().subtract(1, "week").startOf("day");
        break;
      case "monthly":
        return moment().subtract(1, "month").startOf("day");
        break;
      case "daily":
        return moment().startOf("day");
        break;
    }
  },

  @computed("period")
  endDate(period) {
    if (period === "all") return null;

    return moment().endOf("day");
  },

  actions: {
    changePeriod(period) {
      DiscourseURL.routeTo(this._reportsForPeriodURL(period));
    }
  },

  _reportsForPeriodURL(period) {
    return `/admin/dashboard_next?period=${period}`;
  }
});
