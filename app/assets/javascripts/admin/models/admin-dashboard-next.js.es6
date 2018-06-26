import { ajax } from "discourse/lib/ajax";

const ATTRIBUTES = ["disk_space", "updated_at", "last_backup_taken_at"];

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

      model.set("reports", json.reports);
      model.set("version_check", json.version_check);

      const attributes = {};
      ATTRIBUTES.forEach(a => (attributes[a] = json[a]));
      model.set("attributes", attributes);

      model.set("loaded", true);

      return model;
    });
  },

  /**
    Only fetch the list of problems that should be rendered on the dashboard.
    The model will only have its "problems" attribute set.

    @method fetchProblems
    @return {jqXHR} a jQuery Promise object
  **/
  fetchProblems: function() {
    return ajax("/admin/dashboard/problems.json", {
      type: "GET",
      dataType: "json"
    }).then(function(json) {
      var model = AdminDashboardNext.create(json);
      model.set("loaded", true);
      return model;
    });
  }
});

export default AdminDashboardNext;
