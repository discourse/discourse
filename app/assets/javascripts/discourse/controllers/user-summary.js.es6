import computed from 'ember-addons/ember-computed-decorators';

// should be kept in sync with 'UserSummary::MAX_BADGES'
const MAX_BADGES = 6;

export default Ember.Controller.extend({
  userController: Ember.inject.controller('user'),
  user: Ember.computed.alias('userController.model'),

  @computed("model.badges.length")
  moreBadges(badgesLength) { return badgesLength >= MAX_BADGES; },
});
