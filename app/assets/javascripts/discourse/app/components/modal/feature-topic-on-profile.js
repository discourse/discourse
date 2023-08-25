import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";

export default class FeatureTopicOnProfile extends Component {
  @tracked newFeaturedTopic = null;
  @tracked saving = false;

  get noTopicSelected() {
    return !this.newFeaturedTopic;
  }

  @action
  async save() {
    try {
      this.saving = true;
      await ajax(`/u/${this.args.model.user.username}/feature-topic`, {
        type: "PUT",
        data: { topic_id: this.newFeaturedTopic.id },
      });

      this.args.model.setFeaturedTopic(this.newFeaturedTopic);
      this.args.closeModal();
    } catch (error) {
      popupAjaxError(error);
    } finally {
      this.saving = false;
    }
  }

  @action
  newTopicSelected(topic) {
    this.newFeaturedTopic = topic;
  }
}
