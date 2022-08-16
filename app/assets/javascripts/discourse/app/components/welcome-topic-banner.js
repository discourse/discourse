import Component from "@glimmer/component";
import { action } from "@ember/object";
import { getOwner } from "discourse-common/lib/get-owner";
import Topic from "discourse/models/topic";
import Composer from "discourse/models/composer";
import { inject as service } from "@ember/service";

export default class WelcomeTopicBanner extends Component {
  @service siteSettings;
  @service store;

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
          post.topic.setProperties({
            draft_key: Composer.EDIT,
            "details.can_edit": true,
          });
          topicController.send("editPost", post);
        });
    });
  }
}
