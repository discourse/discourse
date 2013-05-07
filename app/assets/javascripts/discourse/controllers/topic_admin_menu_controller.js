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
  },

  autoClose: function() {
    var modalController = this.get('controllers.modal');
    if (modalController) {
      var v = Discourse.EditTopicAutoCloseView.create();
      v.set('topic', this.get('content'));
      modalController.show(v);
    }
  }

});
