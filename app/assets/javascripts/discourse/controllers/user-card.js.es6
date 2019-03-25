import {
  default as DiscourseURL,
  userPath,
  groupPath
} from "discourse/lib/url";

export default Ember.Controller.extend({
  topic: Ember.inject.controller(),
  application: Ember.inject.controller(),

  actions: {
    togglePosts(user) {
      const topicController = this.get("topic");
      topicController.send("toggleParticipant", user);
    },

    showUser(user) {
      DiscourseURL.routeTo(userPath(user.username_lower));
    },

    showGroup(group) {
      DiscourseURL.routeTo(groupPath(group.name));
    }
  }
});
