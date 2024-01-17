import Controller from "@ember/controller";
import { action, computed } from "@ember/object";
import { inject as service } from "@ember/service";
import discourseComputed from "discourse-common/utils/decorators";

export default class AdminDashboardModerationController extends Controller {
  @service modal;

  queryParams = ["period"];

  period = "monthly";
  endDate = moment().locale("en").utc().endOf("day");
  _startDate;

  @computed("_startDate", "period")
  get startDate() {
    if (this._startDate) {
      return this._startDate;
    }

    const fullDay = moment().locale("en").utc().endOf("day");

    switch (this.period) {
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
  }

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

  @discourseComputed("endDate")
  lastWeekFilters(endDate) {
    const lastWeek = moment()
      .locale("en")
      .utc()
      .endOf("day")
      .subtract(1, "week");

    return { lastWeek, endDate };
  }

  @action
  setCustomDateRange(_startDate, endDate) {
    this.setProperties({ _startDate, endDate });
  }

  @action
  setPeriod(period) {
    this.setProperties({ period, _startDate: null });
  }
}
