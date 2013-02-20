(function() {

  window.Discourse.UserStreamView = Ember.View.extend(Discourse.Scrolling, {
    templateName: 'user/stream',
    currentUserBinding: 'Discourse.currentUser',
    userBinding: 'controller.content',
    scrolled: function(e) {
      var $userStreamBottom, docViewBottom, docViewTop, position, windowHeight,
        _this = this;
      $userStreamBottom = jQuery('#user-stream-bottom');
      if ($userStreamBottom.data('loading')) {
        return;
      }
      if (!($userStreamBottom && (position = $userStreamBottom.position()))) {
        return;
      }
      docViewTop = jQuery(window).scrollTop();
      windowHeight = jQuery(window).height();
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
      return this.unbindScrolling();
    },
    didInsertElement: function() {
      var _this = this;
      Discourse.MessageBus.subscribe("/users/" + (this.get('user.username').toLowerCase()), function(data) {
        return _this.get('user').loadUserAction(data);
      });
      return this.bindScrolling();
    }
  });

}).call(this);
