import discourseComputed from "discourse-common/utils/decorators";
import Controller from "@ember/controller";
import PeriodComputationMixin from "admin/mixins/period-computation";

export default Controller.extend(PeriodComputationMixin, {
  @discourseComputed
  flagsStatusOptions() {
    return {
      table: {
        total: false,
        perPage: 10
      }
    };
  },

  @discourseComputed
  userFlaggingRatioOptions() {
    return {
      table: {
        total: false,
        perPage: 10
      }
    };
  },

  @discourseComputed("startDate", "endDate")
  filters(startDate, endDate) {
    return { startDate, endDate };
  },

  @discourseComputed("lastWeek", "endDate")
  lastWeekfilters(startDate, endDate) {
    return { startDate, endDate };
  },

  _reportsForPeriodURL(period) {
    return Discourse.getURL(`/admin/dashboard/moderation?period=${period}`);
  }
});
