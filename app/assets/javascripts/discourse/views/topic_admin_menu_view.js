(function() {

  window.Discourse.TopicAdminMenuView = Em.View.extend({
    willDestroyElement: function() {
      return jQuery('html').off('mouseup.discourse-topic-admin-menu');
    },
    didInsertElement: function() {
      var _this = this;
      return jQuery('html').on('mouseup.discourse-topic-admin-menu', function(e) {
        var $target;
        $target = jQuery(e.target);
        if ($target.is('button') || _this.$().has($target).length === 0) {
          return _this.get('controller').hide();
        }
      });
    }
  });

}).call(this);
