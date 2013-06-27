/**
  This view is used for rendering the topic admin menu

  @class TopicAdminMenuView
  @extends Discourse.View
  @namespace Discourse
  @module Discourse
**/
Discourse.TopicAdminMenuView = Discourse.View.extend({

  willDestroyElement: function() {
    $('html').off('mouseup.discourse-topic-admin-menu');
  },

  didInsertElement: function() {
    var topicAdminMenuView = this;
    $('html').on('mouseup.discourse-topic-admin-menu', function(e) {
      var $target = $(e.target);
      if ($target.is('button') || topicAdminMenuView.$().has($target).length === 0) {
        topicAdminMenuView.get('controller').hide();
      }
    });
  }

});


