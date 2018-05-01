import { ajax } from "discourse/lib/ajax";
import Report from "admin/models/report";

const ATTRIBUTES = [ "disk_space", "updated_at", "last_backup_taken_at"];

const REPORTS = [ "global_reports", "user_reports" ];

const AdminDashboardNext = Discourse.Model.extend({});

AdminDashboardNext.reopenClass({
  /**
    Fetch all dashboard data. This can be an expensive request when the cached data
    has expired and the server must collect the data again.

    @method find
    @return {jqXHR} a jQuery Promise object
  **/
  find() {
    return ajax("/admin/dashboard-next.json").then(function(json) {
      var model = AdminDashboardNext.create();

      const reports = {};
      REPORTS.forEach(name => json[name].forEach(r => {
        if (!reports[name]) reports[name] = {};
        reports[name][r.type] = Report.create(r);
      }));
      model.set("reports", reports);

      const attributes = {};
      ATTRIBUTES.forEach(a => attributes[a] = json[a]);
      model.set("attributes", attributes);

      model.set("loaded", true);

      return model;
    });
  }
});

export default AdminDashboardNext;
