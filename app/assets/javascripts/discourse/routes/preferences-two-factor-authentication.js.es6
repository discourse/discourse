import RestrictedUserRoute from "discourse/routes/restricted-user";

export default RestrictedUserRoute.extend({
  renderTemplate() {
    return this.render({ into: 'user' });
  },

  // A bit odd, but if we leave to /preferences we need to re-render that outlet
  deactivate() {
    this._super();
    this.render('preferences', { into: 'user', controller: 'preferences' });
  },

  setupController(controller, model) {
    controller.set('model', model);

    if (!model.get('enabledTwoFactorAuthentication')) {
      Discourse.ajax(model.get('path') + '/preferences/two_factor_authentication/provisioning_url.json').then(function(result) {
        controller.set('twoFactorAuthenticationData', result.otp);
      });
    }
  }

});

