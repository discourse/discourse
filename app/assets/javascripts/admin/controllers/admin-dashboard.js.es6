import AdminDashboard from "admin/models/admin-dashboard";
import Report from "admin/models/report";
import AdminUser from "admin/models/admin-user";
import computed from "ember-addons/ember-computed-decorators";

const ATTRIBUTES = [
  "disk_space",
  "admins",
  "moderators",
  "silenced",
  "suspended",
  "top_traffic_sources",
  "top_referred_topics",
  "updated_at"
];

const REPORTS = [
  "global_reports",
  "page_view_reports",
  "private_message_reports",
  "http_reports",
  "user_reports",
  "mobile_reports"
];

// This controller supports the default interface when you enter the admin section.
export default Ember.Controller.extend({
  loading: null,
  versionCheck: null,
  dashboardFetchedAt: null,
  exceptionController: Ember.inject.controller("exception"),

  fetchDashboard() {
    if (
      !this.get("dashboardFetchedAt") ||
      moment()
        .subtract(30, "minutes")
        .toDate() > this.get("dashboardFetchedAt")
    ) {
      this.set("loading", true);
      AdminDashboard.find()
        .then(d => {
          this.set("dashboardFetchedAt", new Date());

          REPORTS.forEach(name =>
            this.set(name, d[name].map(r => Report.create(r)))
          );

          const topReferrers = d.top_referrers;
          if (topReferrers && topReferrers.data) {
            d.top_referrers.data = topReferrers.data.map(user =>
              AdminUser.create(user)
            );
            this.set("top_referrers", topReferrers);
          }

          ATTRIBUTES.forEach(a => this.set(a, d[a]));
        })
        .catch(e => {
          this.get("exceptionController").set("thrown", e.jqXHR);
          this.replaceRoute("exception");
        })
        .finally(() => {
          this.set("loading", false);
        });
    }
  },

  @computed("updated_at")
  updatedTimestamp(updatedAt) {
    return moment(updatedAt).format("LLL");
  },

  actions: {
    showTrafficReport() {
      this.set("showTrafficReport", true);
    }
  }
});
