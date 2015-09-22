import RestrictedUserRoute from "discourse/routes/restricted-user";

export default RestrictedUserRoute.extend({
  model: function() {
    return this.modelFor('user');
  },

  renderTemplate: function() {
    this.render({ into: 'user' });
  },

  setupController: function(controller, model) {
    controller.setProperties({ model, newBio: model.get('bio_raw') });
  },

  // A bit odd, but if we leave to /preferences we need to re-render that outlet
  deactivate: function() {
    this._super();
    this.render('preferences', { into: 'user', controller: 'preferences' });
  },

  actions: {
    changeAbout: function() {
      var route = this;
      var controller = route.controllerFor('preferences/about');

      controller.setProperties({ saving: true });
      return controller.get('model').save().then(function() {
        controller.set('saving', false);
        route.transitionTo('user.index');
      }, function() {
        // model failed to save
        controller.set('saving', false);
        alert(I18n.t('generic_error'));
      });
    }
  }

});
