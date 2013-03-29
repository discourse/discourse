/**
  A model that stores all or some data that is displayed on the dashboard.

  @class AdminDashboard
  @extends Discourse.Model
  @namespace Discourse
  @module Discourse
**/

Discourse.AdminDashboard = Discourse.Model.extend({});

Discourse.AdminDashboard.reopenClass({

  /**
    Fetch all dashboard data. This can be an expensive request when the cached data
    has expired and the server must collect the data again.

    @method find
    @return {jqXHR} a jQuery Promise object
  **/
  find: function() {
    var model = Discourse.AdminDashboard.create();
    return $.ajax(Discourse.getURL("/admin/dashboard"), {
      type: 'GET',
      dataType: 'json',
      success: function(json) {
        model.mergeAttributes(json);
        model.set('loaded', true);
      }
    });
  },

  /**
    Only fetch the list of problems that should be rendered on the dashboard.
    The model will only have its "problems" attribute set.

    @method fetchProblems
    @return {jqXHR} a jQuery Promise object
  **/
  fetchProblems: function() {
    var model = Discourse.AdminDashboard.create();
    return $.ajax(Discourse.getURL("/admin/dashboard/problems"), {
      type: 'GET',
      dataType: 'json',
      success: function(json) {
        model.mergeAttributes(json);
        model.set('loaded', true);
      }
    });
  }
});
