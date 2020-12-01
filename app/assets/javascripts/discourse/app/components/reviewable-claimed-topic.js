import Component from "@ember/component";
import { ajax } from "discourse/lib/ajax";
import discourseComputed from "discourse-common/utils/decorators";
import { popupAjaxError } from "discourse/lib/ajax-error";

export default Component.extend({
  tagName: "",

  @discourseComputed
  enabled() {
    return this.siteSettings.reviewable_claiming !== "disabled";
  },

  actions: {
    unclaim() {
      ajax(`/reviewable_claimed_topics/${this.topicId}`, {
        type: "DELETE",
      }).then(() => {
        this.set("claimedBy", null);
      });
    },

    claim() {
      let claim = this.store.createRecord("reviewable-claimed-topic");

      claim
        .save({ topic_id: this.topicId })
        .then(() => {
          this.set("claimedBy", this.currentUser);
        })
        .catch(popupAjaxError);
    },
  },
});
