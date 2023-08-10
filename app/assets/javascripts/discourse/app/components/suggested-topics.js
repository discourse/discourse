import { computed } from "@ember/object";
import Component from "@ember/component";
import discourseComputed from "discourse-common/utils/decorators";
import { inject as service } from "@ember/service";

export default Component.extend({
  tagName: "",
  moreTopicsPreferenceTracking: service(),
  listId: "suggested-topics",

  suggestedTitleLabel: computed("topic", function () {
    const href = this.currentUser && this.currentUser.pmPath(this.topic);
    if (this.topic.get("isPrivateMessage") && href) {
      return "suggested_topics.pm_title";
    } else {
      return "suggested_topics.title";
    }
  }),

  @discourseComputed("moreTopicsPreferenceTracking.preference")
  hidden(preference) {
    return this.site.mobileView && preference !== this.listId;
  },
});
