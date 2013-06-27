/**
  This view handles rendering of a user's stream

  @class UserStreamView
  @extends Discourse.View
  @namespace Discourse
  @uses Discourse.Scrolling
  @module Discourse
**/
Discourse.UserStreamView = Discourse.View.extend(Discourse.Scrolling, {
  templateName: 'user/stream',

  scrolled: function(e) {

    var $userStreamBottom = $('#user-stream-bottom');
    if ($userStreamBottom.data('loading')) return;

    var position = $userStreamBottom.position();
    if (!($userStreamBottom && position)) return;

    var docViewTop = $(window).scrollTop();
    var windowHeight = $(window).height();
    var docViewBottom = docViewTop + windowHeight;

    if (position.top < docViewBottom) {
      $userStreamBottom.data('loading', true);
      this.set('loading', true);

      var userStreamView = this;
      var user = this.get('stream.user');
      var stream = this.get('stream');

      stream.findItems().then(function() {
        userStreamView.set('loading', false);
        Em.run.schedule('afterRender', function() {
          $userStreamBottom.data('loading', null);
        });
      });
    }
  },

  willDestroyElement: function() {
    this.unbindScrolling();
  },

  didInsertElement: function() {
    this.bindScrolling();
  }

});


Discourse.View.registerHelper('userStream', Discourse.UserStreamView);