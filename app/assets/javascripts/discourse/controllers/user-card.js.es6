import Controller from "@ember/controller";
import {
  default as DiscourseURL,
  userPath,
  groupPath
} from "discourse/lib/url";

export default Controller.extend({
  topic: Ember.inject.controller(),
  router: Ember.inject.service(),

  actions: {
    togglePosts(user) {
      const topicController = this.topic;
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
