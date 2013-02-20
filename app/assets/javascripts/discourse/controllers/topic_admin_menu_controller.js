(function() {

  Discourse.TopicAdminMenuController = Ember.ObjectController.extend({
    visible: false,
    show: function() {
      return this.set('visible', true);
    },
    hide: function() {
      return this.set('visible', false);
    }
  });

}).call(this);
