Discourse.GroupRoute = Discourse.Route.extend({

  model: function(params) {
    return Discourse.Group.find(params.name);
  },

});
