/**
  This controller supports the admin menu on topics

  @class TopicAdminMenuController
  @extends Discourse.ObjectController
  @namespace Discourse
  @module Discourse
**/
Discourse.TopicAdminMenuController = Discourse.ObjectController.extend({
  visible: false,
  needs: ['modal'],

  show: function() {
    this.set('visible', true);
  },

  hide: function() {
    this.set('visible', false);
  }

});
