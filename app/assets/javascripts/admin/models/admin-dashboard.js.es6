
const AdminDashboard = Discourse.Model.extend({});

AdminDashboard.reopenClass({

  /**
    Fetch all dashboard data. This can be an expensive request when the cached data
    has expired and the server must collect the data again.

    @method find
    @return {jqXHR} a jQuery Promise object
  **/
  find: function() {
    return Discourse.ajax("/admin/dashboard.json").then(function(json) {
      var model = AdminDashboard.create(json);
      model.set('loaded', true);
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
    return Discourse.ajax("/admin/dashboard/problems.json", {
      type: 'GET',
      dataType: 'json'
    }).then(function(json) {
      var model = AdminDashboard.create(json);
      model.set('loaded', true);
      return model;
    });
  }
});

export default AdminDashboard;
