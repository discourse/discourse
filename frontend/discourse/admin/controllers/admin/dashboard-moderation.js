import { computed } from "@ember/object";
import AdminDashboardTabController from "../admin-dashboard-tab";

export default class AdminDashboardModerationController extends AdminDashboardTabController {
  @computed
  get flagsStatusOptions() {
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

  @computed
  get userFlaggingRatioOptions() {
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

  @computed("endDate")
  get lastWeekFilters() {
    const lastWeek = moment()
      .locale("en")
      .utc()
      .endOf("day")
      .subtract(1, "week");

    return { lastWeek, endDate: this.endDate };
  }
}
