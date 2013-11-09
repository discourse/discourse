Discourse.UserTopicListRoute = Discourse.Route.extend({

  renderTemplate: function() {
    this.render('paginated_topic_list', {into: 'user', outlet: 'userOutlet'});
  },

  setupController: function(controller, model) {
    this.controllerFor('user_activity').set('userActionType', this.get('userActionType'));
    controller.set('model', model);
    this.controllerFor('user').set('indexStream', false);
  }
});

function createPMRoute(viewName, path, type) {
  return Discourse.UserTopicListRoute.extend({
    userActionType: Discourse.UserAction.TYPES.messages_received,

    model: function() {
      return Discourse.TopicList.find('topics/' + path + '/' + this.modelFor('user').get('username_lower'));
    },

    setupController: function(controller, model) {
      this._super.apply(this, arguments);
      controller.set('hideCategories', true);
      this.controllerFor('user').setProperties({
        pmView: viewName,
        indexStream: false
      });
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