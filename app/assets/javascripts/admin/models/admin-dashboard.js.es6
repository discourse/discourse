import { ajax } from "discourse/lib/ajax";

const AdminDashboard = Discourse.Model.extend({});

AdminDashboard.reopenClass({
  /**
    Fetch all dashboard data. This can be an expensive request when the cached data
    has expired and the server must collect the data again.

    @method find
    @return {jqXHR} a jQuery Promise object
  **/
  find: function() {
    return ajax("/admin/dashboard-old.json").then(function(json) {
      var model = AdminDashboard.create(json);
      model.set("loaded", true);
      return model;
    });
  }
});

export default AdminDashboard;
