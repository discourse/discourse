import ShowFooter from "discourse/mixins/show-footer";

export default Discourse.Route.extend(ShowFooter, {
  actions: {
    didTransition: function() {
      return true;
    }
  },

  model: function() {
    return this.modelFor('group').findMembers();
  },

  // afterModel: function(model) {
  //   var self = this;
  //   return model.findMembers().then(function(result) {
  //     self.set('_members', result);
  //   });
  // },

    setupController: function(controller, model) {
      // controller.set('model', this.get('_members'));
    controller.set('model', model);
    this.controllerFor('group').set('showing', 'members');
  }

});
