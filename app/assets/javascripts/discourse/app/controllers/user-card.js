import { inject as service } from "@ember/service";
import Controller, { inject as controller } from "@ember/controller";
import DiscourseURL, { userPath, groupPath } from "discourse/lib/url";

export default Controller.extend({
  topic: controller(),
  router: service(),

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
