import computed from "ember-addons/ember-computed-decorators";
import Report from "admin/models/report";
import AdminDashboardNext from "admin/models/admin-dashboard-next";
import PeriodComputationMixin from "admin/mixins/period-computation";

export default Ember.Controller.extend(PeriodComputationMixin, {
  isLoading: false,
  dashboardFetchedAt: null,
  exceptionController: Ember.inject.controller("exception"),

  @computed
  flagsStatusOptions() {
    return {
      table: {
        total: false,
        perPage: 10
      }
    };
  },

  @computed("reports.[]")
  flagsStatusReport(reports) {
    return reports.find(x => x.type === "flags_status");
  },

  @computed("reports.[]")
  postEditsReport(reports) {
    return reports.find(x => x.type === "post_edits");
  },

  fetchDashboard() {
    if (this.get("isLoading")) return;

    if (
      !this.get("dashboardFetchedAt") ||
      moment()
        .subtract(30, "minutes")
        .toDate() > this.get("dashboardFetchedAt")
    ) {
      this.set("isLoading", true);

      AdminDashboardNext.fetchModeration()
        .then(model => {
          const reports = model.reports.map(x => Report.create(x));
          this.setProperties({
            dashboardFetchedAt: new Date(),
            model,
            reports
          });
        })
        .catch(e => {
          this.get("exceptionController").set("thrown", e.jqXHR);
          this.replaceRoute("exception");
        })
        .finally(() => {
          this.set("isLoading", false);
        });
    }
  },

  _reportsForPeriodURL(period) {
    return Discourse.getURL(`/admin/dashboard/moderation?period=${period}`);
  }
});
