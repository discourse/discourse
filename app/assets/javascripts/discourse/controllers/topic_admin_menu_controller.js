/**
  This controller supports the admin menu on topics

  @class TopicAdminMenuController
  @extends Discourse.ObjectController
  @namespace Discourse
  @module Discourse
**/
Discourse.TopicAdminMenuController = Discourse.ObjectController.extend({
  menuVisible: false,
  needs: ['modal'],

  show: function() {
    this.set('menuVisible', true);
  },

  hide: function() {
    this.set('menuVisible', false);
  }

});
