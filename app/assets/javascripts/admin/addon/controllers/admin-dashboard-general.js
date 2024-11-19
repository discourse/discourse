import { inject as controller } from "@ember/controller";
import { computed } from "@ember/object";
import { service } from "@ember/service";
import { setting } from "discourse/lib/computed";
import getURL from "discourse-common/lib/get-url";
import { makeArray } from "discourse-common/lib/helpers";
import discourseComputed from "discourse-common/utils/decorators";
import { i18n } from "discourse-i18n";
import AdminDashboard from "admin/models/admin-dashboard";
import Report from "admin/models/report";
import AdminDashboardTabController from "./admin-dashboard-tab";

function staticReport(reportType) {
  return computed("reports.[]", function () {
    return makeArray(this.reports).find((report) => report.type === reportType);
  });
}

export default class AdminDashboardGeneralController extends AdminDashboardTabController {
  @service router;
  @service siteSettings;
  @controller("exception") exceptionController;

  isLoading = false;
  dashboardFetchedAt = null;

  @setting("log_search_queries") logSearchQueriesEnabled;

  @staticReport("users_by_type") usersByTypeReport;
  @staticReport("users_by_trust_level") usersByTrustLevelReport;
  @staticReport("storage_report") storageReport;

  @discourseComputed("siteSettings.dashboard_general_tab_activity_metrics")
  activityMetrics(metrics) {
    return (metrics || "").split("|").filter(Boolean);
  }

  @computed("siteSettings.dashboard_hidden_reports")
  get hiddenReports() {
    return (this.siteSettings.dashboard_hidden_reports || "")
      .split("|")
      .filter(Boolean);
  }

  @computed("activityMetrics", "hiddenReports")
  get isActivityMetricsVisible() {
    return (
      this.activityMetrics.length &&
      this.activityMetrics.some((x) => !this.hiddenReports.includes(x))
    );
  }

  @computed("hiddenReports")
  get isSearchReportsVisible() {
    return ["top_referred_topics", "trending_search"].some(
      (x) => !this.hiddenReports.includes(x)
    );
  }

  @computed("hiddenReports")
  get isCommunityHealthVisible() {
    return [
      "consolidated_page_views",
      "site_traffic",
      "signups",
      "topics",
      "posts",
      "dau_by_mau",
      "daily_engaged_users",
      "new_contributors",
    ].some((x) => !this.hiddenReports.includes(x));
  }

  @discourseComputed
  today() {
    return moment().locale("en").utc().endOf("day");
  }

  @computed("startDate", "endDate")
  get filters() {
    return { startDate: this.startDate, endDate: this.endDate };
  }

  @discourseComputed
  activityMetricsFilters() {
    const lastMonth = moment()
      .locale("en")
      .utc()
      .startOf("day")
      .subtract(1, "month");

    return {
      startDate: lastMonth,
      endDate: this.today,
    };
  }

  @discourseComputed
  topReferredTopicsOptions() {
    return {
      table: { total: false, limit: 8 },
    };
  }

  @discourseComputed
  siteTrafficOptions() {
    return {
      stackedChart: { hiddenLabels: ["page_view_other", "page_view_crawler"] },
    };
  }

  @discourseComputed
  topReferredTopicsFilters() {
    return {
      startDate: moment().subtract(6, "days").startOf("day"),
      endDate: this.today,
    };
  }

  @discourseComputed
  trendingSearchFilters() {
    return {
      startDate: moment().subtract(1, "month").startOf("day"),
      endDate: this.today,
    };
  }

  @discourseComputed
  trendingSearchOptions() {
    return {
      table: { total: false, limit: 8 },
    };
  }

  @discourseComputed
  trendingSearchDisabledLabel() {
    return i18n("admin.dashboard.reports.trending_search.disabled", {
      basePath: getURL(""),
    });
  }

  fetchDashboard() {
    if (this.isLoading) {
      return;
    }

    if (
      !this.dashboardFetchedAt ||
      moment().subtract(30, "minutes").toDate() > this.dashboardFetchedAt
    ) {
      this.set("isLoading", true);

      AdminDashboard.fetchGeneral()
        .then((adminDashboardModel) => {
          this.setProperties({
            dashboardFetchedAt: new Date(),
            model: adminDashboardModel,
            reports: makeArray(adminDashboardModel.reports).map((x) =>
              Report.create(x)
            ),
          });
        })
        .catch((e) => {
          this.exceptionController.set("thrown", e.jqXHR);
          this.router.replaceWith("exception");
        })
        .finally(() => this.set("isLoading", false));
    }
  }
}
