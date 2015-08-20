import UserBadge from 'discourse/models/user-badge';
import RestrictedUserRoute from "discourse/routes/restricted-user";

export default RestrictedUserRoute.extend({
  model: function() {
    return UserBadge.findByUsername(this.modelFor('user').get('username'));
  },

  renderTemplate: function() {
    return this.render({ into: 'user' });
  },

  // A bit odd, but if we leave to /preferences we need to re-render that outlet
  deactivate: function() {
    this._super();
    this.render('preferences', { into: 'user', controller: 'preferences' });
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

