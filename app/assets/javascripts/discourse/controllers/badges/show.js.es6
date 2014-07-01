/**
  Controller for showing a particular badge.

  @class BadgesShowController
  @extends Discourse.ObjectController
  @namespace Discourse
  @module Discourse
**/
export default Discourse.ObjectController.extend({
  layoutClass: function(){
    var ub = this.get("userBadges");
    if(ub && ub[0] && ub[0].post_id){
      return "user-badge-with-posts";
    } else {
      return "user-badge-no-posts";
    }
  }.property("userBadges"),

  grantDates: Em.computed.mapBy('userBadges', 'grantedAt'),
  minGrantedAt: Em.computed.min('grantDates'),

  canLoadMore: function() {
    if (this.get('userBadges')) {
      return this.get('model.grant_count') > this.get('userBadges.length');
    } else {
      return false;
    }
  }.property('model.grant_count', 'userBadges.length')
});
