/**
  Controller for showing a particular badge.

  @class BadgesShowController
  @extends Discourse.ObjectController
  @namespace Discourse
  @module Discourse
**/
Discourse.BadgesShowController = Discourse.ObjectController.extend({
  grantDates: Em.computed.mapBy('userBadges', 'grantedAt'),
  minGrantedAt: Em.computed.min('grantDates'),

  moreUserCount: function() {
    if (this.get('userBadges')) {
      return this.get('model.grant_count') - this.get('userBadges.length');
    } else {
      return 0;
    }
  }.property('model.grant_count', 'userBadges.length'),

  showMoreUsers: Em.computed.gt('moreUserCount', 0)
});
