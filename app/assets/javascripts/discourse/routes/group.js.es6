export default Discourse.Route.extend({

  model: function(params) {
    return Discourse.Group.find(params.name);
  },

  serialize: function(model) {
    return { name: model.get('name').toLowerCase() };
  },

  afterModel: function(model) {
    var self = this;
    return Discourse.Group.findGroupCounts(model.get('name')).then(function (counts) {
      self.set('counts', counts);
    });
  },

  setupController: function(controller, model) {
    controller.setProperties({
      model: model,
      counts: this.get('counts')
    });
  }
});
