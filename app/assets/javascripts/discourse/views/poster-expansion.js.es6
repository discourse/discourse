/**
  Shows expanded details for a poster

  @class PosterExpansionView
  @namespace Discourse
  @module Discourse
**/

var clickOutsideEventName = "mousedown.outside-poster-expansion";

export default Discourse.View.extend({
  elementId: 'poster-expansion',
  classNameBindings: ['controller.visible::hidden', 'controller.showBadges'],

  // Position the expansion when the post changes
  _visibleChanged: function() {
    var post = this.get('controller.model'),
        div = this.$();

    Em.run.schedule('afterRender', function() {
      if (post) {
        var $post = $('#' + post.get('postElementId')),
            $avatar = $('.topic-avatar img.avatar', $post),
            position = $avatar.offset();

        if (position) {
          position.left += $avatar.width() + 5;
          div.css(position);
        }
      }
    });
  }.observes('controller.model'),

  didInsertElement: function() {
    var self = this;
    $('html').off(clickOutsideEventName).on(clickOutsideEventName, function(e) {

      if (self.get('controller.visible')) {
        var $target = $(e.target);
        if ($target.closest('.trigger-expansion').length > 0) { return; }
        if (self.$().has(e.target).length !== 0) { return; }

        self.get('controller').close();
      }

      return true;
    });
  },

  willDestroyElement: function() {
    $('html').off(clickOutsideEventName);
  }

});
