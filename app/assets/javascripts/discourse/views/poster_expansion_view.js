/**
  Shows expanded details for a poster

  @class PosterExpansionView
  @namespace Discourse
  @module Discourse
**/
Discourse.PosterExpansionView = Discourse.View.extend({
  elementId: 'poster-expansion',
  classNameBindings: ['controller.model::hidden'],

  // Position the expansion when the model changes
  _modelChanged: function() {
    var post = this.get('controller.post'),
        self = this;

    Em.run.schedule('afterRender', function() {
      if (post) {
        var $post = $('#' + post.get('postElementId')),
            $avatar = $('.topic-meta-data img.avatar', $post),
            position = $avatar.offset();

        position.left += $avatar.width() + 5;
        self.$().css(position);
      }
    });

  }.observes('controller.model'),

  didInsertElement: function() {
    var self = this;
    $('html').on('mousedown.outside-poster-expansion', function(e) {
      if (self.$().has(e.target).length !== 0) { return; }
      self.get('controller').set('model', null);
      return true;
    });
  },

  willDestroyElement: function() {
    $('html').off('mousedown.outside-poster-expansion');
  }

});