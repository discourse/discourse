/**
  The common route stuff for a user's preference

  @class PreferencesRoute
  @extends Discourse.RestrictedUserRoute
  @namespace Discourse
  @module Discourse
**/
Discourse.PreferencesRoute = Discourse.RestrictedUserRoute.extend({
  model: function() {
    return this.modelFor('user');
  },

  renderTemplate: function() {
    this.render('preferences', { into: 'user', outlet: 'userOutlet', controller: 'preferences' });
  },

  setupController: function(controller, model) {
    controller.set('model', model);
    this.controllerFor('user').set('indexStream', false);
  },

  actions: {
    showAvatarSelector: function() {
      Discourse.Route.showModal(this, 'avatarSelector');
      // all the properties needed for displaying the avatar selector modal
      var avatarSelector = this.modelFor('user').getProperties(
        'username', 'email',
        'has_uploaded_avatar', 'use_uploaded_avatar',
        'gravatar_template', 'uploaded_avatar_template');
      this.controllerFor('avatarSelector').setProperties(avatarSelector);
    },

    saveAvatarSelection: function() {
      var user = this.modelFor('user');
      var avatarSelector = this.controllerFor('avatarSelector');
      // sends the information to the server if it has changed
      if (avatarSelector.get('use_uploaded_avatar') !== user.get('use_uploaded_avatar')) {
        user.toggleAvatarSelection(avatarSelector.get('use_uploaded_avatar'));
      }
      // saves the data back
      user.setProperties(avatarSelector.getProperties(
        'has_uploaded_avatar',
        'use_uploaded_avatar',
        'gravatar_template',
        'uploaded_avatar_template'
      ));
      user.set('avatar_template', avatarSelector.get('avatarTemplate'));
      avatarSelector.send('closeModal');
    }
  }
});

/**
  The route for editing a user's "About Me" bio.

  @class PreferencesAboutRoute
  @extends Discourse.RestrictedUserRoute
  @namespace Discourse
  @module Discourse
**/
Discourse.PreferencesAboutRoute = Discourse.RestrictedUserRoute.extend({
  model: function() {
    return this.modelFor('user');
  },

  renderTemplate: function() {
    this.render({ into: 'user', outlet: 'userOutlet' });
  },

  setupController: function(controller, model) {
    controller.setProperties({ model: model, newBio: model.get('bio_raw') });
  },

  // A bit odd, but if we leave to /preferences we need to re-render that outlet
  exit: function() {
    this._super();
    this.render('preferences', { into: 'user', outlet: 'userOutlet', controller: 'preferences' });
  },

  events: {
    changeAbout: function() {
      var route = this;
      var controller = route.controllerFor('preferencesAbout');

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

/**
  The route for editing a user's email

  @class PreferencesEmailRoute
  @extends Discourse.RestrictedUserRoute
  @namespace Discourse
  @module Discourse
**/
Discourse.PreferencesEmailRoute = Discourse.RestrictedUserRoute.extend({
  model: function() {
    return this.modelFor('user');
  },

  renderTemplate: function() {
    this.render({ into: 'user', outlet: 'userOutlet' });
  },

  setupController: function(controller, model) {
    controller.setProperties({ model: model, newEmail: model.get('email') });
  },

  // A bit odd, but if we leave to /preferences we need to re-render that outlet
  exit: function() {
    this._super();
    this.render('preferences', { into: 'user', outlet: 'userOutlet', controller: 'preferences' });
  }
});

/**
  The route for updating a user's username

  @class PreferencesUsernameRoute
  @extends Discourse.RestrictedUserRoute
  @namespace Discourse
  @module Discourse
**/
Discourse.PreferencesUsernameRoute = Discourse.RestrictedUserRoute.extend({
  model: function() {
    return this.modelFor('user');
  },

  renderTemplate: function() {
    return this.render({ into: 'user', outlet: 'userOutlet' });
  },

  // A bit odd, but if we leave to /preferences we need to re-render that outlet
  exit: function() {
    this._super();
    this.render('preferences', { into: 'user', outlet: 'userOutlet', controller: 'preferences' });
  },

  setupController: function(controller, user) {
    controller.setProperties({ model: user, newUsername: user.get('username') });
  }
});
