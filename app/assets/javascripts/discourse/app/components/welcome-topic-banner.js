import GlimmerComponent from "discourse/components/glimmer";
import { action } from "@ember/object";
import { getOwner } from "discourse-common/lib/get-owner";
import Topic from "discourse/models/topic";
import Composer from "discourse/models/composer";

export default class WelcomeTopicBanner extends GlimmerComponent {
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
  }
}
