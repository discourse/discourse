import Component from "@ember/component";
import discourseComputed from "discourse-common/utils/decorators";
import getURL from "discourse-common/lib/get-url";
import { inject as service } from "@ember/service";

export default Component.extend({
  tagName: "",
  moreTopicsPreferenceTracking: service(),
  listId: "related-Messages",

  @discourseComputed("moreTopicsPreferenceTracking.preference")
  hidden(preference) {
    return this.site.mobileView && preference !== this.listId;
  },

  @discourseComputed("topic")
  targetUser(topic) {
    if (!topic || !topic.isPrivateMessage) {
      return;
    }

    const allowedUsers = topic.details.allowed_users;

    if (
      topic.relatedMessages &&
      topic.relatedMessages.length >= 5 &&
      allowedUsers.length === 2 &&
      topic.details.allowed_groups.length === 0 &&
      allowedUsers.find((u) => u.username === this.currentUser.username)
    ) {
      return allowedUsers.find((u) => u.username !== this.currentUser.username);
    }
  },

  @discourseComputed
  searchLink() {
    return getURL(
      `/search?expanded=true&q=%40${this.targetUser.username}%20in%3Apersonal-direct`
    );
  },
});
