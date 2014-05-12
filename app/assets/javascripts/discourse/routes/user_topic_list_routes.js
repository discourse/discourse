Discourse.UserTopicListRoute = Discourse.Route.extend({
  renderTemplate: function() {
    this.render('user_topics_list', {into: 'user', outlet: 'userOutlet'});
  },

  setupController: function(controller, model) {
    this.controllerFor('user').set('indexStream', false);
    this.controllerFor('user_activity').set('userActionType', this.get('userActionType'));
    this.controllerFor('user_topics_list').setProperties({
      model: model,
      hideCategory: false,
      showParticipants: false
    });
  }
});

function createPMRoute(viewName, path) {
  return Discourse.UserTopicListRoute.extend({
    userActionType: Discourse.UserAction.TYPES.messages_received,

    model: function() {
      return Discourse.TopicList.find('topics/' + path + '/' + this.modelFor('user').get('username_lower'));
    },

    setupController: function() {
      this._super.apply(this, arguments);
      this.controllerFor('user_topics_list').setProperties({
        hideCategory: true,
        showParticipants: true
      });
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

Discourse.UserActivityStarredRoute = Discourse.UserTopicListRoute.extend({
  userActionType: Discourse.UserAction.TYPES.starred,

  model: function() {
    return Discourse.TopicList.find('starred', { user_id: this.modelFor('user').get('id') });
  }
});
