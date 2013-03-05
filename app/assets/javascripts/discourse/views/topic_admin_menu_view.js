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
    var _this = this;
    return $('html').on('mouseup.discourse-topic-admin-menu', function(e) {
      var $target;
      $target = $(e.target);
      if ($target.is('button') || _this.$().has($target).length === 0) {
        return _this.get('controller').hide();
      }
    });
  }

});


