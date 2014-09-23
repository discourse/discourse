export default Ember.Route.extend({

  serialize: function(model) {
    return {content_type: model.get('content_type')};
  },

  model: function(params) {
    return Discourse.SiteContent.find(params.content_type);
  }

});
