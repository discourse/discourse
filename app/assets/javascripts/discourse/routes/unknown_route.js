Discourse.UnknownRoute = Discourse.Route.extend({
  model: function() {
    return Discourse.ajax("/404-body", {dataType: 'html'});
  }
});
