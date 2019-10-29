import { inject } from '@ember/controller';
import Controller from "@ember/controller";
import {
  default as DiscourseURL,
  userPath,
  groupPath
} from "discourse/lib/url";

export default Controller.extend({
  topic: inject(),
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
