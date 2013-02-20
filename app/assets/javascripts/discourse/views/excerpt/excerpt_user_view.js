(function() {

  window.Discourse.ExcerptUserView = Ember.View.extend({
    privateMessage: function(e) {
      var $target, composerController, post, postView, url, username;
      $target = this.get("link");
      postView = Ember.View.views[$target.closest('.ember-view')[0].id];
      post = postView.get("post");
      url = post.get("url");
      username = post.get("username");
      Discourse.router.route('/users/' + Discourse.currentUser.username.toLowerCase() + "/private-messages");
      /* TODO figure out a way for it to open the composer cleanly AFTER the navigation happens.
      */

      composerController = Discourse.get('router.composerController');
      return composerController.open({
        action: Discourse.Composer.PRIVATE_MESSAGE,
        usernames: username,
        archetypeId: 'private_message',
        draftKey: 'new_private_message',
        reply: window.location.href.split("/").splice(0, 3).join("/") + url
      });
    }
  });

}).call(this);
