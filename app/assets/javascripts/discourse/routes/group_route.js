Discourse.GroupRoute = Discourse.Route.extend({

  model: function() {
    return Discourse.AdminGroup.create();
  },

});
