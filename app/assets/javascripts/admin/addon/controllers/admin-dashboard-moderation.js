import { computed } from "@ember/object";
import discourseComputed from "discourse/lib/decorators";
import AdminDashboardTabController from "./admin-dashboard-tab";

export default class AdminDashboardModerationController extends AdminDashboardTabController {
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

  @computed("startDate", "endDate")
  get filters() {
    return { startDate: this.startDate, endDate: this.endDate };
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
}
