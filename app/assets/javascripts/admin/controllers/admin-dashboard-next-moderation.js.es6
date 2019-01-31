import computed from "ember-addons/ember-computed-decorators";
import PeriodComputationMixin from "admin/mixins/period-computation";

export default Ember.Controller.extend(PeriodComputationMixin, {
  @computed
  flagsStatusOptions() {
    return {
      table: {
        total: false,
        perPage: 10
      }
    };
  },

  @computed
  userFlaggingRatioOptions() {
    return {
      table: {
        total: false,
        perPage: 10
      }
    };
  },

  @computed("startDate", "endDate")
  filters(startDate, endDate) {
    return { startDate, endDate };
  },

  @computed("lastWeek", "endDate")
  lastWeekfilters(startDate, endDate) {
    return { startDate, endDate };
  },

  _reportsForPeriodURL(period) {
    return Discourse.getURL(`/admin/dashboard/moderation?period=${period}`);
  }
});
