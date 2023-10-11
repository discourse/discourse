import Controller from "@ember/controller";
import { action, computed } from "@ember/object";
import { inject as service } from "@ember/service";
import getURL from "discourse-common/lib/get-url";
import discourseComputed from "discourse-common/utils/decorators";
import PeriodComputationMixin from "admin/mixins/period-computation";
import CustomDateRangeModal from "../components/modal/custom-date-range";

export default class AdminDashboardModerationController extends Controller.extend(
  PeriodComputationMixin
) {
  @service modal;

  @discourseComputed
  flagsStatusOptions() {
    return {
      table: {
        total: false,
        perPage: 10,
      },
    };
  }

  @computed("siteSettings.dashboard_hidden_reports")
  get isModeratorsActivityVisible() {
    return !(this.siteSettings.dashboard_hidden_reports || "")
      .split("|")
      .filter(Boolean)
      .includes("moderators_activity");
  }

  @discourseComputed
  userFlaggingRatioOptions() {
    return {
      table: {
        total: false,
        perPage: 10,
      },
    };
  }

  @discourseComputed("startDate", "endDate")
  filters(startDate, endDate) {
    return { startDate, endDate };
  }

  @discourseComputed("lastWeek", "endDate")
  lastWeekfilters(startDate, endDate) {
    return { startDate, endDate };
  }

  _reportsForPeriodURL(period) {
    return getURL(`/admin/dashboard/moderation?period=${period}`);
  }

  @action
  setCustomDateRange(startDate, endDate) {
    this.setProperties({ startDate, endDate });
  }

  @action
  openCustomDateRangeModal() {
    this.modal.show(CustomDateRangeModal, {
      model: {
        startDate: this.startDate,
        endDate: this.endDate,
        setCustomDateRange: this.setCustomDateRange,
      },
    });
  }
}
