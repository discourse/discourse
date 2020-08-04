import getURL from "discourse-common/lib/get-url";
import discourseComputed from "discourse-common/utils/decorators";
import Controller from "@ember/controller";
import PeriodComputationMixin from "admin/mixins/period-computation";
import { computed } from "@ember/object";

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

  isModeratorsActivityVisible: computed(
    "siteSettings.dashboard_hidden_reports",
    function() {
      return !(this.siteSettings.dashboard_hidden_reports || "")
        .split("|")
        .filter(Boolean)
        .includes("moderators_activity");
    }
  ),

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
    return getURL(`/admin/dashboard/moderation?period=${period}`);
  }
});
