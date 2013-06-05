Discourse.AdminGroupsRoute = Discourse.Route.extend({

  model: function() {
    return Discourse.Group.findAll();
  },

  renderTemplate: function() {
    this.render('admin/templates/groups',{into: 'admin/templates/admin'});
  }

});

