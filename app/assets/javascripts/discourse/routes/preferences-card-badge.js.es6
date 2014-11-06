export default Discourse.RestrictedUserRoute.extend({
  model: function() {
    return Discourse.UserBadge.findByUsername(this.modelFor('user').get('username'));
  },

  renderTemplate: function() {
    return this.render({ into: 'user', outlet: 'userOutlet' });
  },

  // A bit odd, but if we leave to /preferences we need to re-render that outlet
  deactivate: function() {
    this._super();
    this.render('preferences', { into: 'user', outlet: 'userOutlet', controller: 'preferences' });
  },

  setupController: function(controller, model) {
    controller.set('model', model);
    controller.set('user', this.modelFor('user'));

    model.forEach(function(userBadge) {
      if (userBadge.get('badge.image') === controller.get('user.card_image_badge')) {
        controller.set('selectedUserBadgeId', userBadge.get('id'));
      }
    });
  }
});

