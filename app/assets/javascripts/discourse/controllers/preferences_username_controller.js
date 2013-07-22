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


/**
  This controller supports actions related to updating one's username

  @class PreferencesUsernameController
  @extends Discourse.ObjectController
  @namespace Discourse
  @module Discourse
**/
Discourse.PreferencesUsernameController = Discourse.ObjectController.extend({
  taken: false,
  saving: false,
  error: false,
  errorMessage: null,
  newUsername: null,

  newUsernameEmpty: Em.computed.empty('newUsername'),
  saveDisabled: Em.computed.or('saving', 'newUsernameEmpty', 'taken', 'unchanged', 'errorMessage'),
  unchanged: Discourse.computed.propertyEqual('newUsername', 'username'),

  checkTaken: function() {
    if( this.get('newUsername') && this.get('newUsername').length < 3 ) {
      this.set('errorMessage', I18n.t('user.name.too_short'));
    } else {
      var preferencesUsernameController = this;
      this.set('taken', false);
      this.set('errorMessage', null);
      if (this.blank('newUsername')) return;
      if (this.get('unchanged')) return;
      Discourse.User.checkUsername(this.get('newUsername')).then(function(result) {
        if (result.errors) {
          preferencesUsernameController.set('errorMessage', result.errors.join(' '));
        } else if (result.available === false) {
          preferencesUsernameController.set('taken', true);
        }
      });
    }
  }.observes('newUsername'),

  saveButtonText: function() {
    if (this.get('saving')) return I18n.t("saving");
    return I18n.t("user.change");
  }.property('saving'),

  changeUsername: function() {
    var preferencesUsernameController = this;
    return bootbox.confirm(I18n.t("user.change_username.confirm"), I18n.t("no_value"), I18n.t("yes_value"), function(result) {
      if (result) {
        preferencesUsernameController.set('saving', true);
        preferencesUsernameController.get('content').changeUsername(preferencesUsernameController.get('newUsername')).then(function() {
          Discourse.URL.redirectTo("/users/" + preferencesUsernameController.get('newUsername').toLowerCase() + "/preferences");
        }, function() {
          // error
          preferencesUsernameController.set('error', true);
          preferencesUsernameController.set('saving', false);
        });
      }
    });
  }
});


