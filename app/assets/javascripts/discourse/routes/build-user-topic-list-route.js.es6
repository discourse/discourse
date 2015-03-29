import UserTopicListRoute from "discourse/routes/user-topic-list";
import ShowFooter from "discourse/mixins/show-footer";

// A helper to build a user topic list route
export default function (viewName, path) {
  return UserTopicListRoute.extend(ShowFooter, {
    userActionType: Discourse.UserAction.TYPES.messages_received,

    actions: {
      didTransition: function() {
        this.controllerFor("user-topics-list")._showFooter();
        return true;
      }
    },

    model: function() {
      return Discourse.TopicList.find('topics/' + path + '/' + this.modelFor('user').get('username_lower'));
    },

    setupController: function() {
      this._super.apply(this, arguments);

      this.controllerFor('user_topics_list').setProperties({
        hideCategory: true,
        showParticipants: true
      });

      this.controllerFor('user').set('pmView', viewName);
      this.controllerFor('search').set('contextType', 'private_messages');
    },

    deactivate: function(){
      this.controllerFor('search').set('contextType', 'user');
    }
  });
}
