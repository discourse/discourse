import ShowFooter from "discourse/mixins/show-footer";

export default Discourse.Route.extend(ShowFooter, {
  model: function() {
    return this.modelFor('group');
  },

  afterModel: function(model) {
    var self = this;
    return model.findMembers().then(function(result) {
      self.set('_members', result);
    });
  },

  setupController: function(controller) {
    controller.set('model', this.get('_members'));
    this.controllerFor('group').set('showing', 'members');
  }

});

