/**
  This controller supports actions on the site header

  @class HeaderController
  @extends Discourse.Controller
  @namespace Discourse
  @module Discourse
**/
Discourse.HeaderController = Discourse.Controller.extend({
  topic: null,
  showExtraInfo: null,

  toggleStar: function() {
    var topic = this.get('topic');
    if (topic) topic.toggleStar();
    return false;
  },

  categories: function() {
    return Discourse.Category.list();
  }.property(),

  showFavoriteButton: function() {
    return this.get('currentUser') && !this.get('topic.isPrivateMessage');
  }.property('currentUser', 'topic.isPrivateMessage'),

  mobileDevice: Ember.computed.alias('session.mobileDevice'),
  mobileView: Ember.computed.alias('session.mobileView'),

  toggleMobileView: function() {
    window.location.assign(window.location.pathname + '?mobile_view=' + (this.get('session.mobileView') ? '0' : '1'));
  }

});


