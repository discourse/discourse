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

    var $userStreamBottom = $('#user-stream-bottom');
    if ($userStreamBottom.data('loading')) return;

    var position = $userStreamBottom.position();
    if (!($userStreamBottom && position)) return;

    var docViewTop = $(window).scrollTop();
    var windowHeight = $(window).height();
    var docViewBottom = docViewTop + windowHeight;
    this.set('loading', true);
    if (position.top < docViewBottom) {
      $userStreamBottom.data('loading', true);
      this.set('loading', true);

      var userStreamView = this;
      return this.get('controller.content').loadMoreUserActions().then(function() {
        userStreamView.set('loading', false);
        Em.run.next(function() {
          $userStreamBottom.data('loading', null);
        });
      });
    }
  },

  willDestroyElement: function() {
    Discourse.MessageBus.unsubscribe("/users/" + (this.get('user.username').toLowerCase()));
    this.unbindScrolling();
  },

  didInsertElement: function() {
    var userSteamView = this;
    Discourse.MessageBus.subscribe("/users/" + (this.get('user.username').toLowerCase()), function(data) {
      userSteamView.get('user').loadUserAction(data);
    });
    this.bindScrolling();
  }

});


