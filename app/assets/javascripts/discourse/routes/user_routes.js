/**
  Handles routes related to users.

  @class UserRoute
  @extends Discourse.Route
  @namespace Discourse
  @module Discourse
**/
Discourse.UserRoute = Discourse.Route.extend({

  model: function(params) {

    // If we're viewing the currently logged in user, return that object
    // instead.
    var currentUser = Discourse.User.current();
    if (currentUser && (params.username.toLowerCase() === currentUser.get('username_lower'))) {
      return currentUser;
    }

    return Discourse.User.create({username: params.username});
  },

  afterModel: function() {
    return this.modelFor('user').findDetails();
  },

  serialize: function(params) {
    if (!params) return {};
    return { username: Em.get(params, 'username').toLowerCase() };
  },

  setupController: function(controller, user) {
    controller.set('model', user);

    // Add a search context
    this.controllerFor('search').set('searchContext', user.get('searchContext'));
  },

  activate: function() {
    this._super();
    var user = this.modelFor('user');
    Discourse.MessageBus.subscribe("/users/" + user.get('username_lower'), function(data) {
      user.loadUserAction(data);
    });
  },

  deactivate: function() {
    this._super();
    Discourse.MessageBus.unsubscribe("/users/" + this.modelFor('user').get('username_lower'));

    // Remove the search context
    this.controllerFor('search').set('searchContext', null);
  }

});

/**
  This route shows who a user has invited

  @class UserInvitedRoute
  @extends Discourse.Route
  @namespace Discourse
  @module Discourse
**/
Discourse.UserInvitedRoute = Discourse.Route.extend({
  renderTemplate: function() {
    this.render({ into: 'user', outlet: 'userOutlet' });
  },

  model: function() {
    return Discourse.InviteList.findInvitedBy(this.modelFor('user'));
  }
});


/**
  The base route for showing a user's activity

  @class UserActivityRoute
  @extends Discourse.Route
  @namespace Discourse
  @module Discourse
**/
Discourse.UserActivityRoute = Discourse.Route.extend({
  renderTemplate: function() {
    this.render('user_activity', {into: 'user', outlet: 'userOutlet' });
  },

  model: function() {
    return this.modelFor('user');
  },

  setupController: function(controller, user) {
    this.controllerFor('userActivity').set('model', user);

    var composerController = this.controllerFor('composer');
    controller.set('model', user);
    if (Discourse.User.current()) {
      Discourse.Draft.get('new_private_message').then(function(data) {
        if (data.draft) {
          composerController.open({
            draft: data.draft,
            draftKey: 'new_private_message',
            ignoreIfChanged: true,
            draftSequence: data.draft_sequence
          });
        }
      });
    }
  }
});
Discourse.UserPrivateMessagesRoute = Discourse.UserActivityRoute.extend({});

/**
  If we request /user/eviltrout without a sub route.

  @class UserIndexRoute
  @extends Discourse.Route
  @namespace Discourse
  @module Discourse
**/
Discourse.UserIndexRoute = Discourse.UserActivityRoute.extend({
  redirect: function() {
    this.transitionTo('userActivity', this.modelFor('user'));
  }
});

/**
  The base route for showing an activity stream.

  @class UserActivityStreamRoute
  @extends Discourse.Route
  @namespace Discourse
  @module Discourse
**/
Discourse.UserActivityStreamRoute = Discourse.Route.extend({
  model: function() {
    return this.modelFor('user').get('stream');
  },

  afterModel: function() {
    return this.modelFor('user').get('stream').filterBy(this.get('userActionType'));
  },

  renderTemplate: function() {
    this.render('user_stream', {into: 'user_activity', outlet: 'activity'});
  },

  setupController: function(controller, model) {
    controller.set('model', model);
    this.controllerFor('user_activity').set('userActionType', this.get('userActionType'));
  }
});

// Build all activity stream routes
['bookmarks', 'edits', 'likes_given', 'likes_received', 'replies', 'posts', 'index'].forEach(function (userAction) {
  Discourse["UserActivity" + userAction.classify() + "Route"] = Discourse.UserActivityStreamRoute.extend({
    userActionType: Discourse.UserAction.TYPES[userAction]
  });
});

Discourse.UserTopicListRoute = Discourse.Route.extend({

  renderTemplate: function() {
    this.render('paginated_topic_list', {into: 'user_activity', outlet: 'activity'});
  },

  setupController: function(controller, model) {
    this.controllerFor('user_activity').set('userActionType', this.get('userActionType'));
    controller.set('model', model);
  }
});

function createPMRoute(viewName, path, type) {
  return Discourse.UserTopicListRoute.extend({
    userActionType: Discourse.UserAction.TYPES.messages_received,

    model: function() {
      return Discourse.TopicList.find('topics/' + path + '/' + this.modelFor('user').get('username_lower'));
    },

    setupController: function(controller, model) {
      this._super(controller, model);
      controller.set('hideCategories', true);
      this.controllerFor('userActivity').set('pmView', viewName);
    }
  });
}

Discourse.UserPrivateMessagesIndexRoute = createPMRoute('index', 'private-messages');
Discourse.UserPrivateMessagesMineRoute = createPMRoute('mine', 'private-messages-sent');
Discourse.UserPrivateMessagesUnreadRoute = createPMRoute('unread', 'private-messages-unread');


Discourse.UserActivityTopicsRoute = Discourse.UserTopicListRoute.extend({
  userActionType: Discourse.UserAction.TYPES.topics,

  model: function() {
    return Discourse.TopicList.find('topics/created-by/' + this.modelFor('user').get('username_lower'));
  }
});

Discourse.UserActivityFavoritesRoute = Discourse.UserTopicListRoute.extend({
  userActionType: Discourse.UserAction.TYPES.favorites,

  model: function() {
    return Discourse.TopicList.find('favorited?user_id=' + this.modelFor('user').get('id'));
  }
});
