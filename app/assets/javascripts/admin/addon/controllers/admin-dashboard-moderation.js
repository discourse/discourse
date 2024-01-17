import { computed } from "@ember/object";
import { inject as service } from "@ember/service";
import discourseComputed from "discourse-common/utils/decorators";
import AdminDashboardTabController from "./admin-dashboard-tab";

export default class AdminDashboardModerationController extends AdminDashboardTabController {
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
