import UserTopicListRoute from "discourse/routes/user-topic-list";

export default UserTopicListRoute.extend({
  userActionType: Discourse.UserAction.TYPES.starred,

  model: function() {
    return Discourse.TopicList.find('starred', { user_id: this.modelFor('user').get('id') });
  }
});
