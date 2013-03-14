Discourse.AdminDashboard = Discourse.Model.extend({});

Discourse.AdminDashboard.reopenClass({
  find: function() {
    var model = Discourse.AdminDashboard.create();
    return $.ajax("/admin/dashboard", {
      type: 'GET',
      success: function(json) {
        model.mergeAttributes(json);
        model.set('loaded', true);
      }
    });
  }
});