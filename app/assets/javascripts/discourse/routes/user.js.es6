const INDEX_STREAM_ROUTES = ["user.deletedPosts", "user.flaggedPosts", "userActivity.index"];

export default Discourse.Route.extend({

  titleToken() {
    const model = this.modelFor('user');
    const username = model.get('username');
    if (username) {
      return [I18n.t("user.profile"), username];
    }
  },

  actions: {
    composePrivateMessage(user, post) {
      const recipient = user ? user.get('username') : '',
          reply = post ? window.location.protocol + "//" + window.location.host + post.get("url") : null;

      return this.controllerFor('composer').open({
        action: Discourse.Composer.PRIVATE_MESSAGE,
        usernames: recipient,
        archetypeId: 'private_message',
        draftKey: 'new_private_message',
        reply: reply
      });
    },

    willTransition(transition) {
      // will reset the indexStream when transitioning to routes that aren't "indexStream"
      // otherwise the "header" will jump
      const isIndexStream = INDEX_STREAM_ROUTES.indexOf(transition.targetName) !== -1;
      this.controllerFor('user').set('indexStream', isIndexStream);
      return true;
    }
  },

  model(params) {
    // If we're viewing the currently logged in user, return that object instead
    const currentUser = this.currentUser;
    if (currentUser && (params.username.toLowerCase() === currentUser.get('username_lower'))) {
      return currentUser;
    }

    return Discourse.User.create({username: params.username});
  },

  afterModel() {
    const user = this.modelFor('user');
    const self = this;

    return user.findDetails().then(function() {
      return user.findStaffInfo();
    }).catch(function() {
      return self.replaceWith('/404');
    });
  },

  serialize(model) {
    if (!model) return {};
    return { username: (Em.get(model, 'username') || '').toLowerCase() };
  },

  setupController(controller, user) {
    controller.set('model', user);
    this.searchService.set('searchContext', user.get('searchContext'));
  },

  activate() {
    this._super();
    const user = this.modelFor('user');
    this.messageBus.subscribe("/users/" + user.get('username_lower'), function(data) {
      user.loadUserAction(data);
    });
  },

  deactivate() {
    this._super();
    this.messageBus.unsubscribe("/users/" + this.modelFor('user').get('username_lower'));

    // Remove the search context
    this.searchService.set('searchContext', null);
  }

});
