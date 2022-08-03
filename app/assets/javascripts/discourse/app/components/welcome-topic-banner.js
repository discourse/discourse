import { getOwner } from "discourse-common/lib/get-owner";
import { action } from "@ember/object";
import Component from "@ember/component";
import Topic from "discourse/models/topic";
import Composer from "discourse/models/composer";
import { on } from "discourse-common/utils/decorators";

export default Component.extend({
  @on("didInsertElement")
  _hideWelcomeTopicRow() {
    document
      .querySelectorAll(
        `tr[data-topic-id='${this.siteSettings.welcome_topic_id}']`
      )[0]
      ?.classList.add("hidden");
  },

  @action
  editWelcomeTopic() {
    const topicController = getOwner(this).lookup("controller:topic");

    Topic.find(this.siteSettings.welcome_topic_id, {}).then((topic) => {
      this.store
        .createRecord("topic", {
          id: topic.id,
          slug: topic.slug,
        })
        .postStream.loadPostByPostNumber(1)
        .then((post) => {
          post.topic.set("draft_key", Composer.EDIT);
          topicController.send("editPost", post);
        });
    });
  },
});
