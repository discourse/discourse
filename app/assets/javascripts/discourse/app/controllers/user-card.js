import Controller, { inject as controller } from "@ember/controller";
import DiscourseURL, { groupPath, userPath } from "discourse/lib/url";

export default Controller.extend({
  topic: controller(),

  actions: {
    filterPosts(user) {
      const topicController = this.topic;
      topicController.send("filterParticipant", user);
    },

    showUser(user) {
      DiscourseURL.routeTo(userPath(user.username_lower));
    },

    showGroup(group) {
      DiscourseURL.routeTo(groupPath(group.name));
    },
  },
});
