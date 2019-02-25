import { ajax } from "discourse/lib/ajax";

const GENERAL_ATTRIBUTES = ["updated_at"];

const AdminDashboardNext = Discourse.Model.extend({});

AdminDashboardNext.reopenClass({
  fetch() {
    return ajax("/admin/dashboard.json").then(json => {
      const model = AdminDashboardNext.create();
      model.set("version_check", json.version_check);
      return model;
    });
  },

  fetchGeneral() {
    return ajax("/admin/dashboard/general.json").then(json => {
      const model = AdminDashboardNext.create();

      const attributes = {};
      GENERAL_ATTRIBUTES.forEach(a => (attributes[a] = json[a]));

      model.setProperties({
        reports: json.reports,
        attributes,
        loaded: true
      });

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
