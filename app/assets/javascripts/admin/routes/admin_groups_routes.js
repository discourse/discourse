Discourse.AdminGroupsRoute = Discourse.Route.extend({
  renderTemplate: function() {
    this.render('admin/templates/groups',{into: 'admin/templates/admin'});
  },

  setupController: function(controller, model) {
    controller.set('model', Discourse.Group.findAll());
  }
});

