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
  currentUserBinding: 'Discourse.currentUser',
  userBinding: 'controller.content',

  scrolled: function(e) {
    var $userStreamBottom, docViewBottom, docViewTop, position, windowHeight,
      _this = this;
    $userStreamBottom = $('#user-stream-bottom');
    if ($userStreamBottom.data('loading')) {
      return;
    }
    if (!($userStreamBottom && (position = $userStreamBottom.position()))) {
      return;
    }
    docViewTop = $(window).scrollTop();
    windowHeight = $(window).height();
    docViewBottom = docViewTop + windowHeight;
    this.set('loading', true);
    if (position.top < docViewBottom) {
      $userStreamBottom.data('loading', true);
      this.set('loading', true);
      return this.get('controller.content').loadMoreUserActions(function() {
        _this.set('loading', false);
        return Em.run.next(function() {
          return $userStreamBottom.data('loading', null);
        });
      });
    }
  },

  willDestroyElement: function() {
    Discourse.MessageBus.unsubscribe("/users/" + (this.get('user.username').toLowerCase()));
    this.unbindScrolling();
  },

  didInsertElement: function() {
    var _this = this;
    Discourse.MessageBus.subscribe("/users/" + (this.get('user.username').toLowerCase()), function(data) {
      _this.get('user').loadUserAction(data);
    });
    this.bindScrolling();
  }

});


