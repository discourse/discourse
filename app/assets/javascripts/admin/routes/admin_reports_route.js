Discourse.AdminReportsRoute = Discourse.Route.extend({
  model: function(params) {
    return(Discourse.Report.find(params.type));
  },

  renderTemplate: function() {
    this.render('admin/templates/reports', {into: 'admin/templates/admin'});
  }
});