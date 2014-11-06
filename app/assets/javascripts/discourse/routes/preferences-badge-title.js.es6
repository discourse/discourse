export default Discourse.RestrictedUserRoute.extend({
  model: function() {
    return Discourse.UserBadge.findByUsername(this.modelFor('user').get('username'));
  },

  renderTemplate: function() {
    return this.render('user/badge-title', { into: 'user', outlet: 'userOutlet' });
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
      if (userBadge.get('badge.name') === controller.get('user.title')) {
        controller.set('selectedUserBadgeId', userBadge.get('id'));
      }
    });
    if (!controller.get('selectedUserBadgeId') && controller.get('selectableUserBadges.length') > 0) {
      controller.set('selectedUserBadgeId', controller.get('selectableUserBadges')[0].get('id'));
    }
  }
});
