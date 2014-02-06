Discourse.GroupRoute = Discourse.Route.extend({

  model: function() {
    return Discourse.Group.create();
  },

});
